import {createServer} from 'node:http';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const upstream = 'https://apibubbler.krackbot.com';
const brandCode = 'Vclean';
const brandId = '87211d7b-1b57-417f-9762-4a5c4d42945a';
const brandHeaders = {'X-Brand-Code':brandCode,'X-Brand-Id':brandId};
const origins = new Set(['http://127.0.0.1:8780','http://localhost:8780','http://127.0.0.1:8766','http://localhost:8766','http://127.0.0.1:8080','http://localhost:8080']);
const getPaths = new Set(['/api/branding/public/Vclean','/api/carousel/public','/api/items/price-list','/api/me','/api/orders','/api/addresses','/api/serviceability/branches','/api/notifications']);
const postPaths = new Set(['/api/auth/customer/otp/request','/api/auth/customer/otp/verify','/api/addresses','/api/feedback/area-request','/api/orders']);
const orderRead = /^\/api\/orders(?:\/[A-Za-z0-9_-]{1,128}(?:\/invoices|\/feedback\/eligibility)?)?$/;
const orderFeedback = /^\/api\/orders\/[A-Za-z0-9_-]{1,128}\/feedback$/;
const addressRecord = /^\/api\/addresses\/[A-Za-z0-9_-]{1,128}$/;
const imagePrefix = '/storage/v1/object/public/assets/catalog-icons/';

// Development only: fixed backend, fixed brand, explicit routes; no credentials are logged.
export function createLocalApiProxy(upstreamFetch = fetch) {
  const imageRequests = new Map();
  async function completeImage(imagePath) {
    if (imageRequests.has(imagePath)) return imageRequests.get(imagePath);
    const request = (async () => {
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const response = await upstreamFetch('https://bubblerdb.krackbot.com'+imagePath,
            {signal:AbortSignal.timeout(20000),redirect:'error'});
          const contentType = response.headers.get('content-type') ?? '';
          if (!response.ok || !/^image\/(png|jpeg|webp)(;|$)/i.test(contentType) || !response.body) {
            await response.body?.cancel();
            throw new Error('Catalogue photo unavailable');
          }
          const reader = response.body.getReader();
          const chunks = []; let size = 0;
          for (;;) {
            const {value,done} = await reader.read();
            if (done) break;
            size += value.length;
            if (size > 15 * 1024 * 1024) {await reader.cancel();throw new Error('Catalogue photo too large');}
            chunks.push(value);
          }
          if (!size) throw new Error('Empty catalogue photo');
          return {contentType,bytes:Buffer.concat(chunks,size)};
        } catch (error) {
          if (attempt === 1) throw error;
        }
      }
    })();
    imageRequests.set(imagePath,request);
    try {return await request;} finally {imageRequests.delete(imagePath);}
  }
  return createServer(async (req,res) => {
    const origin = req.headers.origin;
    const send = (status,message) => {res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify({message}));};
    res.setHeader('Cache-Control','no-store');
    res.setHeader('Vary','Origin');
    if (origin && !origins.has(origin)) return send(403,'Origin not allowed.');
    if (origin) res.setHeader('Access-Control-Allow-Origin',origin);
    res.setHeader('Access-Control-Allow-Methods','GET,POST,PATCH,DELETE,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers','Content-Type,Authorization,X-Brand-Code,X-Brand-Id');
    if (req.method === 'OPTIONS') {res.writeHead(204);res.end();return;}
    try {
      const url = new URL(req.url,'http://127.0.0.1:8781');
      if (req.method === 'GET' && url.pathname.startsWith(imagePrefix)) {
        const fileName = url.pathname.slice(imagePrefix.length);
        if (!/^[A-Za-z0-9._~-]+\.(?:png|jpe?g|webp)$/.test(fileName) || url.search) return send(404,'Unsupported image.');
        const {contentType,bytes} = await completeImage(url.pathname);
        res.setHeader('Cache-Control','public, max-age=600');
        res.writeHead(200,{'Content-Type':contentType,'Content-Length':bytes.length});
        res.end(bytes);
        return;
      }
      const isPost = req.method === 'POST';
      const isPatch = req.method === 'PATCH';
      const isDelete = req.method === 'DELETE';
      const supported = (req.method === 'GET' && (getPaths.has(url.pathname) || orderRead.test(url.pathname))) ||
        (isPost && (postPaths.has(url.pathname) || orderFeedback.test(url.pathname))) ||
        (isPatch && (url.pathname === '/api/me' || addressRecord.test(url.pathname))) ||
        (isDelete && addressRecord.test(url.pathname));
      if (!supported) return send(404,'Unsupported preview endpoint.');
      if ((req.headers['x-brand-code'] && req.headers['x-brand-code'] !== brandCode) ||
          (req.headers['x-brand-id'] && req.headers['x-brand-id'] !== brandId)) return send(403,'Incorrect brand.');
      const headers = {...brandHeaders};
      if (url.pathname === '/api/me' || url.pathname === '/api/orders' || url.pathname.startsWith('/api/orders/') || url.pathname === '/api/addresses' || url.pathname.startsWith('/api/addresses/') || url.pathname === '/api/notifications') {
        if (!/^Bearer \S+$/.test(req.headers.authorization ?? '')) return send(401,'Please sign in.');
        headers.Authorization = req.headers.authorization;
      }
      let body;
      if ((isPost || isPatch || isDelete) && !origin) return send(403,'Use the local app for this action.');
      if (isPost || isPatch) {
        if (!req.headers['content-type']?.startsWith('application/json')) return send(415,'JSON required.');
        let length=0;const chunks=[];
        for await (const chunk of req) {length+=chunk.length;if(length>65536)return send(413,'Request too large.');chunks.push(chunk);}
        let data;try {data=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{return send(400,'Invalid request.');}
        if (!data || typeof data !== 'object' || Array.isArray(data)) return send(400,'Invalid request.');
        let payload;
        const textField=(name,max,required=false)=>typeof data[name]==='string' && data[name].length<=max && (!required || data[name].trim().length>0);
        if (url.pathname.startsWith('/api/auth/customer/otp/')) {
          if (data.brandCode !== brandCode || !/^[6-9]\d{9}$/.test(data.phone ?? '')) return send(400,'Enter a valid mobile number.');
          payload={phone:data.phone,brandCode};
          if (url.pathname.endsWith('/verify')) {
            if (typeof data.otp !== 'string' || !/^\d{6}$/.test(data.otp) || typeof data.requestId !== 'string' || !data.requestId || data.requestId.length>512) return send(400,'Enter the 6-digit code.');
            payload.otp=data.otp;payload.requestId=data.requestId;
          }
        } else if (url.pathname === '/api/me') {
          if (Object.keys(data).some(key=>!['name','email'].includes(key)) || !textField('name',100,true) || (data.email != null && !textField('email',254))) return send(400,'Check your name and email.');
          payload={name:data.name,...(data.email != null ? {email:data.email} : {})};
        } else if (url.pathname === '/api/addresses' || addressRecord.test(url.pathname)) {
          const fields=['label','addressLine','pincode','houseNo','streetArea','city','isDefault','googleMapUrl'];
          if (Object.keys(data).some(key=>!fields.includes(key)) || !textField('label',180,true) || !textField('addressLine',1000,true) || !/^[1-9]\d{5}$/.test(data.pincode ?? '') || typeof data.isDefault !== 'boolean') return send(400,'Check the address details.');
          if (['houseNo','streetArea','city'].some(key=>!textField(key,180,true))) return send(400,'Enter the house, street and city.');
          if (data.googleMapUrl != null && (!textField('googleMapUrl',2000) || !data.googleMapUrl.startsWith('https://'))) return send(400,'Enter a valid Maps link.');
          payload=Object.fromEntries(fields.filter(key=>key in data).map(key=>[key,data[key]]));
        } else if (orderFeedback.test(url.pathname)) {
          if (!Number.isInteger(data.rating) || data.rating<1 || data.rating>5 || (data.message!=null && !textField('message',2000))) return send(400,'Check your rating and comment.');
          payload={rating:data.rating,...(data.message ? {message:data.message}: {})};
        } else if (url.pathname === '/api/orders') {
          payload=data;
        } else {
          const fields=['pincode','addressLine','customerName','customerPhone','customerEmail'];
          if (!/^[1-9]\d{5}$/.test(data.pincode ?? '') || !textField('addressLine',1000,true) || fields.slice(2).some(key=>data[key]!=null && !textField(key,254))) return send(400,'Check the service request details.');
          payload=Object.fromEntries(fields.filter(key=>key in data).map(key=>[key,data[key]]));
        }
        headers['Content-Type']='application/json';body=JSON.stringify(payload);
      }
      const target = new URL(url.pathname + url.search,upstream);
      if (url.pathname === '/api/serviceability/branches') {
        const pincode=url.searchParams.get('pincode');
        if (!/^[1-9]\d{5}$/.test(pincode ?? '')) return send(400,'Enter a valid six-digit pincode.');
        target.searchParams.set('pincode',pincode);
      }
      if (url.pathname === '/api/items/price-list') {
        const branchId = url.searchParams.get('branchId');
        if (!branchId) return send(400,'Select a branch.');
        const brandingResponse = await upstreamFetch(upstream+'/api/branding/public/Vclean', {signal:AbortSignal.timeout(25000),redirect:'error'});
        if (!brandingResponse.ok) return send(502,'Branch directory is unavailable.');
        const branding=await brandingResponse.json();
        if (branding.brandId !== brandId || !branding.branches?.some(b=>b.id===branchId && b.brandId===brandId)) return send(403,'Select a Vclean branch.');
        target.searchParams.set('branchId',branchId);
      }
      const response = await upstreamFetch(target,{method:req.method,headers,body,signal:AbortSignal.timeout(25000),redirect:'error'});
      res.writeHead(response.status,{'Content-Type':'application/json; charset=utf-8'});
      res.end(await response.text());
    } catch {if (!res.headersSent)send(502,'Cannot reach the server. Please try again.');else res.end();}
  });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  createLocalApiProxy().listen(8781,'127.0.0.1',()=>console.log('Local Vclean API relay: http://127.0.0.1:8781'));
}
