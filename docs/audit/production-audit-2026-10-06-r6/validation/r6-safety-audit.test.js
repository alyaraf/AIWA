import { it, expect, vi } from 'vitest';
import { api } from '../api.js';

it('audit: zero search matches suppress the unfiltered oldest open alert read', async () => {
  const seen=[];
  vi.spyOn(globalThis,'fetch').mockImplementation(async (url)=>{
    const u=new URL(url); seen.push(u);
    const filtered=u.searchParams.has('query');
    const content=filtered?[]:[{id:99,bookingId:7,actorName:'Waiting customer',createdAt:'2026-10-06T08:00:00Z',resolved:false}];
    return new Response(JSON.stringify({success:true,data:{content,totalElements:content.length,totalPages:content.length?1:0,number:0}}),
      {status:200,headers:{'Content-Type':'application/json'}});
  });
  const whole=await api.safetyPage({status:'OPEN',page:0,size:10});
  expect(whole.total).toBe(1);
  expect(whole.oldest.id).toBe(99);
  seen.length=0;
  const page=await api.safetyPage({status:'OPEN',query:'no-matching-customer',page:0,size:10});
  expect(page.rows).toEqual([]);
  expect(page.oldest).toBeNull();
  expect(seen).toHaveLength(1);
  expect(seen.some((u)=>u.searchParams.get('order')==='oldest')).toBe(false);
});
