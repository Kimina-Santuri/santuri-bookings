// Shrinks a photo on the member's own device before upload, so listing photos cost little data and storage:
// a centre-cropped square, 640px, WebP where the browser can encode it (JPEG otherwise, e.g. older Safari).
export const PHOTO_SIZE=640,PHOTO_LIMIT=300*1024;

async function decode(file){
 try{return await createImageBitmap(file,{imageOrientation:'from-image'});}
 catch{
  // Older browsers: fall back to an <img>, which also applies the photo's rotation.
  const url=URL.createObjectURL(file);
  try{const img=new Image();img.src=url;await img.decode();return img;}
  catch{throw Error('That photo could not be opened. Try a JPG or PNG.');}
  finally{URL.revokeObjectURL(url);}
 }
}
const encode=(canvas,type,quality)=>new Promise(resolve=>canvas.toBlob(resolve,type,quality));

export async function squarePhoto(file){
 if(!file?.type?.startsWith('image/'))throw Error('Choose a photo (JPG, PNG, WebP or HEIC).');
 if(file.size>25*1024*1024)throw Error('That photo is over 25 MB. Choose a smaller one.');
 const image=await decode(file),w=image.width,h=image.height,side=Math.min(w,h),size=Math.min(PHOTO_SIZE,side);
 const canvas=document.createElement('canvas');canvas.width=canvas.height=size;
 const ctx=canvas.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,size,size);ctx.imageSmoothingQuality='high';
 ctx.drawImage(image,(w-side)/2,(h-side)/2,side,side,0,0,size,size);image.close?.();
 // Step the quality down until it fits; most photos fit at the first step.
 for(const quality of [.8,.65,.5]){
  let blob=await encode(canvas,'image/webp',quality);
  if(blob?.type!=='image/webp')blob=await encode(canvas,'image/jpeg',quality);
  if(blob&&blob.size<=PHOTO_LIMIT)return blob;
 }
 throw Error('That photo could not be made small enough. Try another one.');
}
