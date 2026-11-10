import test from 'node:test';
import assert from 'node:assert/strict';
import {createLocalApiProxy} from './local_api_proxy.mjs';

const brandId='87211d7b-1b57-417f-9762-4a5c4d42945a';
async function withProxy(mock,run){
  const server=createLocalApiProxy(mock);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  try{return await run(`http://127.0.0.1:${server.address().port}`);}
  finally{await new Promise((resolve,reject)=>server.close(e=>e?reject(e):resolve()));}
}
const localHeaders={Origin:'http://127.0.0.1:8780','X-Brand-Code':'Vclean','X-Brand-Id':brandId};
const accountHeaders={...localHeaders,Authorization:'Bearer test-customer-token','Content-Type':'application/json'};
test('customer orders and invoices require bearer auth and retain the fixed brand',async()=>{
  const calls=[];
  await withProxy(async(url,options)=>{calls.push({url:String(url),options});return new Response('[]',{status:200});},async base=>{
    assert.equal((await fetch(base+'/api/orders',{headers:localHeaders})).status,401);
    for(const path of ['/api/orders','/api/orders/order-1','/api/orders/order-1/invoices','/api/orders/order-1/feedback/eligibility','/api/addresses']) {
      assert.equal((await fetch(base+path,{headers:accountHeaders})).status,200);
    }
    assert.equal(calls.length,5);
    assert.ok(calls.every(call=>call.options.headers.Authorization==='Bearer test-customer-token' && call.options.headers['X-Brand-Id']===brandId));
    assert.equal((await fetch(base+'/api/orders/order-1/cancel',{method:'POST',headers:accountHeaders,body:'{}'})).status,404);
  });
});
test('profile PATCH rejects privilege fields and preserves an empty successful response',async()=>{
  const calls=[];
  await withProxy(async(url,options)=>{calls.push({url:String(url),options});return new Response(null,{status:204});},async base=>{
    assert.equal((await fetch(base+'/api/me',{method:'PATCH',headers:accountHeaders,body:JSON.stringify({name:'Customer',role:'ADMIN'})})).status,400);
    assert.equal((await fetch(base+'/api/me',{method:'PATCH',headers:accountHeaders,body:JSON.stringify({name:'Customer'})})).status,204);
    assert.equal(calls.length,1);assert.equal(calls[0].options.method,'PATCH');
    assert.deepEqual(JSON.parse(calls[0].options.body),{name:'Customer'});
  });
});
test('address deletion and feedback are limited to explicit local customer actions',async()=>{
  const calls=[];
  await withProxy(async(url,options)=>{calls.push({url:String(url),options});return new Response(null,{status:204});},async base=>{
    assert.equal((await fetch(base+'/api/addresses/address-1',{method:'DELETE',headers:{Authorization:'Bearer token'}})).status,403);
    assert.equal((await fetch(base+'/api/addresses/address-1',{method:'DELETE',headers:accountHeaders})).status,204);
    assert.equal((await fetch(base+'/api/orders/order-1/feedback',{method:'POST',headers:accountHeaders,body:JSON.stringify({rating:6})})).status,400);
    assert.equal((await fetch(base+'/api/orders/order-1/feedback',{method:'POST',headers:accountHeaders,body:JSON.stringify({rating:5,message:'Good'})})).status,204);
    assert.equal(calls.length,2);
  });
});
test('forwards only a verified Vclean branch with fixed brand headers',async()=>{
  const calls=[];
  await withProxy(async(url,options)=>{
    calls.push({url:String(url),options});
    if(String(url).includes('/branding/public/'))return new Response(JSON.stringify({brandId,branches:[{id:'ours',brandId}]}),{status:200});
    return new Response(JSON.stringify([{itemId:'shirt',name:'Shirt',lines:[{segment:'MEN',service:'IRON',priceRupees:35}]}]),{status:200});
  },async base=>{
    const good=await fetch(base+'/api/items/price-list?branchId=ours',{headers:localHeaders});
    assert.equal(good.status,200);assert.equal((await good.json())[0].name,'Shirt');
    assert.equal(calls[1].options.headers['X-Brand-Id'],brandId);
    assert.equal(new URL(calls[1].url).searchParams.get('branchId'),'ours');
    const bad=await fetch(base+'/api/items/price-list?branchId=foreign',{headers:localHeaders});
    assert.equal(bad.status,403);assert.equal(calls.length,3);
  });
});
test('denies foreign origins, brands, paths and unauthenticated profile reads',async()=>{
  let calls=0;
  await withProxy(async()=>{calls++;return new Response('{}',{status:200});},async base=>{
    assert.equal((await fetch(base+'/api/items/price-list?branchId=ours',{headers:{...localHeaders,Origin:'http://evil.test'}})).status,403);
    assert.equal((await fetch(base+'/api/items/price-list?branchId=ours',{headers:{...localHeaders,'X-Brand-Id':'foreign'}})).status,403);
    assert.equal((await fetch(base+'/api/admin',{headers:localHeaders})).status,404);
    assert.equal((await fetch(base+'/api/me',{headers:localHeaders})).status,401);
    assert.equal(calls,0);
  });
});
test('relays the exact customer OTP contract only after a local user action',async()=>{
  const calls=[];
  await withProxy(async(url,options)=>{
    calls.push({url:String(url),body:JSON.parse(options.body)});
    return new Response(JSON.stringify({requestId:'request-1'}),{status:200});
  },async base=>{
    assert.equal((await fetch(base+'/api/auth/customer/otp/request',{method:'POST',headers:{...localHeaders,'Content-Type':'application/json'},
      body:JSON.stringify({phone:'9876543210',brandCode:'Vclean'})})).status,200);
    assert.deepEqual(calls[0].body,{phone:'9876543210',brandCode:'Vclean'});
    for (const otp of ['1234','12345','1234567','12x456']) {
      assert.equal((await fetch(base+'/api/auth/customer/otp/verify',{method:'POST',headers:{...localHeaders,'Content-Type':'application/json'},
        body:JSON.stringify({phone:'9876543210',otp,requestId:'request-1',brandCode:'Vclean'})})).status,400);
    }
    assert.equal(calls.length,1);
    assert.equal((await fetch(base+'/api/auth/customer/otp/verify',{method:'POST',headers:{...localHeaders,'Content-Type':'application/json'},
      body:JSON.stringify({phone:'9876543210',otp:'012345',requestId:'request-1',brandCode:'Vclean'})})).status,200);
    assert.deepEqual(calls[1].body,{phone:'9876543210',brandCode:'Vclean',otp:'012345',requestId:'request-1'});
    assert.equal((await fetch(base+'/api/auth/customer/otp/request',{method:'POST',headers:{...localHeaders,'Content-Type':'application/json'},
      body:JSON.stringify({phone:'123',brandCode:'Vclean'})})).status,400);
    assert.equal(calls.length,2);
  });
});
test('serves only public catalogue photos from the configured storage host',async()=>{
  const calls=[];
  await withProxy(async(url)=>{calls.push(String(url));return new Response(new Uint8Array([1,2,3]),{status:200,headers:{'content-type':'image/png'}});},async base=>{
    const allowed=await fetch(base+'/storage/v1/object/public/assets/catalog-icons/icon-shirt.png',{headers:localHeaders});
    assert.equal(allowed.status,200);assert.deepEqual([...new Uint8Array(await allowed.arrayBuffer())],[1,2,3]);
    assert.equal(calls[0],'https://bubblerdb.krackbot.com/storage/v1/object/public/assets/catalog-icons/icon-shirt.png');
    assert.equal((await fetch(base+'/storage/v1/object/public/another-brand/logo.png',{headers:localHeaders})).status,404);
    assert.equal((await fetch(base+'/storage/v1/object/public/assets/catalog-icons/../secret.png',{headers:localHeaders})).status,404);
    assert.equal(calls.length,1);
  });
});
test('retries an interrupted photo before returning a complete image',async()=>{
  let calls=0;
  await withProxy(async()=>{
    calls++;
    const body=calls===1 ? new ReadableStream({start(controller){controller.error(new Error('Interrupted download'));}}) : new Uint8Array([1,2,3,4]);
    return new Response(body,{status:200,headers:{'content-type':'image/png'}});
  },async base=>{
    const response=await fetch(base+'/storage/v1/object/public/assets/catalog-icons/icon-shirt.png',{headers:localHeaders});
    assert.equal(response.status,200);assert.equal(response.headers.get('content-length'),'4');
    assert.deepEqual([...new Uint8Array(await response.arrayBuffer())],[1,2,3,4]);assert.equal(calls,2);
  });
});
