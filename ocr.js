/* OCR local: conserva filas aunque la patente sea dudosa; no inventa estados ni importes. */
(function(){
const norm=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
const plateOK=s=>/^(?:[A-Z]{2}\d{3}[A-Z]{2}|[A-Z]{3}\d{3}|[A-Z]\d{3}[A-Z]{3}|[A-Z]{3}\d{2}[A-Z])$/.test(s);
function parse(text){
 const lines=String(text||'').split(/\r?\n/).map(x=>x.trim()).filter(Boolean), groups=[];
 for(const line of lines){
   // Una fila normalmente empieza con número de fila y cochera, o cochera sola.
   const m=line.match(/^(?:(\d{1,3})\s+)?(\d{3,5})\s*[|:;]\s*(.*)$/)||line.match(/^(?:(\d{1,3})\s+)?(\d{3,5})\s+([\w?]{4,10}(?:\s|$).*)$/);
   if(m){groups.push({cochera:m[2],raw:m[3]});continue}
   // También admitir patente al principio si el OCR omitió cochera.
   const p=line.match(/^\s*([A-Za-z]{2}\d{3}[A-Za-z]{2}|[A-Za-z]{3}\d{3}|[A-Za-z]\d{3}[A-Za-z]{3})\b/i);
   if(p){groups.push({cochera:'',raw:line});continue}
   if(groups.length&&/\b(?:PARTICULARES?|ABONADOS?|SI|SÍ|NO)\b/i.test(line))groups.at(-1).raw+=' '+line;
 }
 return groups.map(g=>{
   const s=norm(g.raw), token=s.match(/^\s*([A-Z0-9?]{4,10})\b/)?.[1]||'';
   const typeMatches=[...s.matchAll(/\b(PARTICULARES?|ABONADOS?)\b/g)], type=typeMatches.length===1?(typeMatches[0][0].startsWith('PART')?'PARTICULAR':'ABONADO'):'';
   const before=typeMatches.length===1?s.slice(0,typeMatches[0].index):s;
   // Estado inmediatamente anterior al tipo, ignorando símbolos de desplegable.
   const state=before.match(/\b(SI|NO)\s*[^A-Z0-9]*$/)?.[1]||'';
   const tail=typeMatches.length===1?s.slice(typeMatches[0].index+typeMatches[0][0].length):'';
   const val=tail.match(/\$\s*([\d.,]+)|\b(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d{4,}(?:,\d{1,2})?)\b/);
   let value=null;if(val){let x=val[1]||val[2];x=x.replace(/\./g,'').replace(',','.');const n=Number(x);if(Number.isFinite(n)&&n>=0)value=n}
   return {patente:token,cochera:g.cochera,tipo:type,realizado:state,valor:value,duda:true,observacion:plateOK(token)?'Verificar contra foto':'Patente dudosa: verificar contra foto'};
 });
}
async function read(blob,progress){
 if(!window.Tesseract)await new Promise((resolve,reject)=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/tesseract.js@5.1.1/dist/tesseract.min.js';s.onload=resolve;s.onerror=()=>reject(Error('No se pudo descargar OCR'));document.head.append(s)});
 let worker;try{worker=await Tesseract.createWorker('spa+eng',1,{logger:m=>progress(m.status+' '+Math.round((m.progress||0)*100)+'%')});
 const bmp=await createImageBitmap(blob),c=document.createElement('canvas'),scale=Math.min(2,3400/Math.max(bmp.width,bmp.height));c.width=Math.round(bmp.width*scale);c.height=Math.round(bmp.height*scale);const ctx=c.getContext('2d');ctx.drawImage(bmp,0,0,c.width,c.height);bmp.close();
 await worker.setParameters({tessedit_pageseg_mode:'6',preserve_interword_spaces:'1'});
 const a=(await worker.recognize(c)).data.text;
 await worker.setParameters({tessedit_pageseg_mode:'11'});
 const b=(await worker.recognize(c)).data.text;
 const score=t=>parse(t).reduce((n,r)=>n+1+Number(plateOK(r.patente))+Number(!!r.tipo)+Number(!!r.realizado),0);
 return score(a)>=score(b)?a:b;
 }finally{if(worker)await worker.terminate()}
}
window.bbvaOCR={read,parse};
})();
