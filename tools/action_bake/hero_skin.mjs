// Original ASHWAKE 52px character skin. Deterministic, offline and inspectable.
// Rig and PNG utility attribution: see NOTICE.md and vendor/pixelfx/LICENSE.
import { skeleton } from './vendor/pixelfx/skeleton.mjs';
import { encodePNG } from './vendor/pixelfx/png.mjs';
import { writeFileSync } from 'node:fs';

const W=128,H=96,PX=46,PY=77,S=1.38;
const geometryChecks=[];
const C={
  ink:'#101d27', seam:'#1e3542', dark:'#2c4955', shadow:'#3d606a',
  tealD:'#4c7681',teal:'#639296',tealL:'#8bb6ab',tealHi:'#acd2c1',
  brassD:'#754e3b',brass:'#aa7851',brassL:'#d6aa70',brassHi:'#efd3a0',
  boneD:'#819a9c',bone:'#bacac1',boneL:'#e5ead4',boneHi:'#fff3d6',
  clothD:'#32565d',cloth:'#4e7e80',clothL:'#79aaa0',
  glowD:'#2b8290',glow:'#78d5cd',glowL:'#d5f2dc',
  steelD:'#476c78',steel:'#8cb6bd',steelL:'#cce3d9',white:'#edf6e8',
};
const rgb=h=>[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16),255];
const PA=Object.fromEntries(Object.entries(C).map(([k,v])=>[k,rgb(v)]));
const V=(a,b,t)=>a.map((v,i)=>v+(b[i]-v)*t);
const A=(a,b)=>a.map((v,i)=>v+b[i]);
const D=(a,b)=>a.map((v,i)=>v-b[i]);

class Raster {
  constructor(w=W,h=H){this.w=w;this.h=h;this.buf=new Uint8Array(w*h*4);}
  pixel(x,y,col){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=this.w||y>=this.h)return;this.buf.set(typeof col==='string'?PA[col]:col,(y*this.w+x)*4);}
  poly(p,col){
    let minX=Math.floor(Math.min(...p.map(v=>v[0]))), maxX=Math.ceil(Math.max(...p.map(v=>v[0])));
    let minY=Math.floor(Math.min(...p.map(v=>v[1]))), maxY=Math.ceil(Math.max(...p.map(v=>v[1])));
    for(let y=minY;y<=maxY;y++)for(let x=minX;x<=maxX;x++){
      let inside=false;
      for(let i=0,j=p.length-1;i<p.length;j=i++)if(((p[i][1]>y+.5)!==(p[j][1]>y+.5))&&(x+.5<(p[j][0]-p[i][0])*(y+.5-p[i][1])/(p[j][1]-p[i][1])+p[i][0]))inside=!inside;
      if(inside)this.pixel(x,y,col);
    }
  }
  line(a,b,col,width=1){const n=Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])*2);for(let k=0;k<=n;k++){const p=V(a,b,k/n);for(let dy=0;dy<width;dy++)for(let dx=0;dx<width;dx++)this.pixel(p[0]+dx,p[1]+dy,col);}}
  outline(){
    const b=this.buf.slice();for(let y=0;y<this.h;y++)for(let x=0;x<this.w;x++){
      const at=(y*this.w+x)*4;if(b[at+3])continue;
      if([[-1,0],[1,0],[0,-1],[0,1]].some(([dx,dy])=>{let nx=x+dx,ny=y+dy;return nx>=0&&ny>=0&&nx<this.w&&ny<this.h&&b[(ny*this.w+nx)*4+3]}))this.pixel(x,y,'ink');
    }
  }
  save(path){writeFileSync(path,encodePNG(this.w,this.h,this.buf));}
}

function hero(pose,options={}){
  const raw=skeleton(pose), J=Object.fromEntries(Object.entries(raw.joints).map(([k,v])=>[k,v.map(n=>n*S)]));
  const r=new Raster(), parts=[],modelPoints=[];
  let settleY=0;
  // Rigid local posture rotation is used only for the death collapse. No world
  // translation or run/dodge displacement is ever baked into a clip.
  const T=p=>{if(!pose.roll)return [p[0],p[1]+settleY];const a=pose.roll,c=Math.cos(a),s=Math.sin(a),cx=J.pelvis[0],cy=J.pelvis[1],dx=p[0]-cx,dy=p[1]-cy;return [cx+dx*c-dy*s,(pose.rollHeight??cy)+dx*s+dy*c+settleY];};
  const P=p=>{const q=T(p);return [q[0]+PX,q[1]+PY];};
  const poly=(points,color,z=0)=>{modelPoints.push(...points);parts.push({z,draw:()=>r.poly(points.map(P),color)});};
  const line=(a,b,color,z=0,width=1)=>{modelPoints.push(a,b);parts.push({z,draw:()=>r.line(P(a),P(b),color,width)});};
  const patch=(anchor,points,color,z=0)=>poly(points.map(p=>[anchor[0]+p[0],anchor[1]+p[1]]),color,z);
  const band=(a,b,r1,r2,far=false,materials=['tealD','teal','tealL'],zAdd=0)=>{
    const l=Math.hypot(b[0]-a[0],b[1]-a[1])||1,n=[-(b[1]-a[1])/l,(b[0]-a[0])/l],f=(p,r)=>[p[0]+n[0]*r,p[1]+n[1]*r];
    const z=(a[2]+b[2])/2+zAdd, pal=far?[materials[0],materials[0],materials[1]]:materials;
    poly([f(a,-r1),f(a,r1),f(b,r2),f(b,-r2)],pal[1],z);
    poly([f(a,-r1),f(a,-r1*.2),f(b,-r2*.2),f(b,-r2)],pal[2],z+.02);
    poly([f(a,r1*.45),f(a,r1),f(b,r2),f(b,r2*.45)],pal[0],z+.03);
    return {n,z,f};
  };
  const foot=(side,far)=>{
    const a=J['ankle'+side],toe=J['toe'+side],z=a[2]+.1;
    const lifted=pose[side==='N'?'ffy':'fby'] < -4.5;
    const bottom=lifted?a[1]+3.1:0;
    const x=a[0],y=a[1];
    poly([[x-2.7,y-2],[x+1.4,y-2.6],[x+2.1,bottom-4],[x+6,bottom-3],[x+7,bottom-1],[x+6,bottom],[x-3,bottom],[x-3.3,bottom-2]],far?'dark':'seam',z);
    poly([[x-2,y-2],[x+1,y-2],[x+2,bottom-3],[x+5,bottom-3],[x+5,bottom-2],[x-1,bottom-2]],far?'shadow':'tealD',z+.01);
    line([x-1,bottom-1],[x+6,bottom-1],far?'tealD':'teal',z+.02);
  };
  const leg=(side,far)=>{
    const hip=J['hip'+side],knee=J['knee'+side],ankle=J['ankle'+side];
    band(hip,knee,3.8,2.7,far,['dark','shadow','tealD']);
    band(V(knee,ankle,.1),V(knee,ankle,.9),2.7,2.0,far,['shadow','tealD','tealL'],.15);
    const z=knee[2]+.3;
    patch(knee,[[-2.5,-1.7],[1,-2.4],[2.5,-.5],[1,1.5],[-1.7,1.6]],far?'brassD':'brass',z);
    if(!far)line([knee[0]-1,knee[1]-1],[knee[0]+1,knee[1]-1],'brassL',z+.02);
    foot(side,far);
  };
  leg('F',true);leg('N',false);
  const pelvis=J.pelvis,chest=J.chest,neck=J.neck,head=J.head;
  const lean=(chest[0]-pelvis[0])*.8;
  // Short divided courier coat: its opening preserves the leg silhouette.
  const flow=pose.flow??0;
  patch(pelvis,[[-6,-1],[-1,-1],[1,7],[-5,10],[-7,5]],'clothD',-4);
  patch(pelvis,[[-5,-1],[-2,0],[-1,6],[-5,8]],'cloth',-3.98);
  patch(pelvis,[[0,0],[5,-1],[8+flow*.16,6],[3,8]],'cloth',3);
  patch(pelvis,[[3,0],[5,-1],[7+flow*.16,6],[5,6]],'clothL',3.02);
  // Narrow flexible waist, explicitly separated from the ribcage and belt.
  band(pelvis,chest,3.4,4.6,false,['seam','dark','shadow'],0);
  poly([[chest[0]-5.4,chest[1]-3.1],[chest[0]+4,chest[1]-3.7],[chest[0]+5.4,chest[1]+1],[pelvis[0]+3.3,pelvis[1]-2],[pelvis[0]-3.4,pelvis[1]-2],[chest[0]-5.4,chest[1]+3.1]],'teal',2);
  poly([[chest[0]-5.4,chest[1]-3.1],[chest[0]-1,chest[1]-3.2],[pelvis[0]-.8,pelvis[1]-2],[pelvis[0]-3.4,pelvis[1]-2]],'tealL',2.02);
  poly([[chest[0]+1,chest[1]-3.4],[chest[0]+4,chest[1]-3.7],[chest[0]+5.4,chest[1]+1],[pelvis[0]+3.3,pelvis[1]-2],[pelvis[0]+1,pelvis[1]-2]],'tealD',2.04);
  // Diagonal harness and luminous relay sigil, not a decorative scatter of pixels.
  line([chest[0]-3.5,chest[1]-2.8],[pelvis[0]+2.1,pelvis[1]-2.8],'brassD',2.1,2);
  line([chest[0]-3.5,chest[1]-2.8],[pelvis[0]+1.1,pelvis[1]-2.8],'brass',2.12);
  patch(chest,[[1,-1],[4,-1],[4,2],[2,4],[1,3]],'ink',2.2);
  line([chest[0]+2,chest[1]],[chest[0]+3,chest[1]],'glowL',2.23);
  line([chest[0]+2,chest[1]+1],[chest[0]+2,chest[1]+2],'glow',2.23);
  // Copper waist belt, asymmetric small satchel; no bulky mid-body blob.
  patch(pelvis,[[-4.2,-2.6],[3.8,-2.5],[4.4,0],[-4.3,.2]],'brassD',4);
  line([pelvis[0]-4,pelvis[1]-2],[pelvis[0]+3,pelvis[1]-2],'brassL',4.02);
  patch(pelvis,[[-1,-2],[1,-2],[1,0],[-1,0]],'brassHi',4.04);
  patch(pelvis,[[-6,-2],[-3,-2],[-3,3],[-6,4]],'brassD',4.1);
  line([pelvis[0]-6,pelvis[1]-1],[pelvis[0]-4,pelvis[1]-1],'brass',4.12);
  const arm=(side,far)=>{
    const sh=J['shoulder'+side],el=J['elbow'+side],ha=J['hand'+side];
    band(sh,el,2.5,1.7,far,['dark','cloth','clothL']);
    band(V(el,ha,.08),V(el,ha,.84),2.5,1.9,far,['tealD','teal','boneD'],.2);
    const z=ha[2]+.3;
    patch(ha,[[-1.7,-2],[1.5,-1.8],[2.2,.3],[1,2],[-1.6,1.5]],far?'shadow':'dark',z);
    line([ha[0]-1,ha[1]-1],[ha[0]+1,ha[1]-1],far?'tealD':'brass',z+.01);
    if(!far){
      // One copper pauldron, with a separate lower plate and a pale top bevel.
      patch(sh,[[-3.4,-2.7],[-.8,-4.1],[2.7,-3.5],[4,-1],[3.8,2.1],[.3,3],[-3.1,1]],'brassD',sh[2]+3.2);
      patch(sh,[[-3.1,-2.1],[-.7,-3.5],[2.4,-3],[3.2,-.8],[2.1,1],[-.4,1.4],[-2.7,.3]],'brass',sh[2]+3.22);
      patch(sh,[[-2.7,-2.2],[-.7,-3.4],[2,-2.9],[1,-1.8],[-2,-1]],'brassL',sh[2]+3.24);
      line([sh[0]-.7,sh[1]-3.2],[sh[0]+1.2,sh[1]-2.8],'brassHi',sh[2]+3.26);
    }
  };
  arm('F',true);arm('N',false);
  // The scarf has a deliberate broad shape, tapered fold, and a split tip.
  const sc=J.neck, tail=-10-Math.max(0,flow)*.45,dy=pose.scY??1;
  patch(sc,[[-2,-1],[-7,-1],[-11+tail*.45,-3+dy],[-9+tail*.65,1+dy],[-11+tail*.65,4+dy],[-6,3],[-1,3]],'clothD',-6);
  patch(sc,[[-3,-1],[-7,0],[-10+tail*.45,-2+dy],[-8+tail*.60,1+dy],[-6,2],[-3,2]],'teal',-5.98);
  line([sc[0]-7,sc[1]],[sc[0]-10+tail*.45,sc[1]-2+dy],'tealL',-5.96);
  patch(sc,[[-3.5,-1.8],[3,-2],[4,1.5],[1,3.2],[-3.2,1.6]],'cloth',10);
  line([sc[0]-3,sc[1]-1],[sc[0]+2,sc[1]-1],'tealL',10.02);
  // Original ceramic face: forward brow, narrow dark eye slit and angular chin.
  const hx=head[0],hy=head[1],hz=12;
  patch(head,[[-4,-4.7],[-1.6,-6],[2,-5.4],[4.4,-3.5],[4.7,.4],[2.3,4.4],[-1.5,4.2],[-4.4,1]],'dark',hz);
  patch(head,[[-2.5,-4.5],[.5,-5],[3.3,-3.3],[4.7,-1],[5.3,1],[3,4.5],[0,3.5],[-1.5,1]],'bone',hz+.02);
  patch(head,[[-2.3,-4.1],[.2,-4.7],[3,-3.1],[3.6,-1.2],[.5,-1.2],[-1,1]],'boneL',hz+.04);
  patch(head,[[3.7,-.8],[5.1,1],[3,4.2],[2,2.7],[2.2,.5]],'boneD',hz+.06);
  line([hx+1,hy-1],[hx+4,hy-1],'ink',hz+.1);
  line([hx+3,hy-1],[hx+4,hy-1],'glow',hz+.12);
  line([hx+2,hy+2],[hx+3,hy+2],'seam',hz+.14);
  // Broken copper halo / communication fin, not horns or a stock helmet.
  patch(head,[[-4,-4],[-3,-6],[-1,-6],[-1,-5],[-3,-4],[-3,-1],[-4,-1]],'brass',hz+.16);
  line([hx-3,hy-5],[hx-1,hy-5],'brassL',hz+.18);
  patch(head,[[-5,-2],[-3,-2],[-3,0],[-5,0]],'brassD',hz+.2);
  // The relay blade is slim, single-edged with a clipped point and luminous inset.
  let weaponBounds=null, weaponSocketPoints=null;
  if(pose.weapon){
    const ha=J.handN,ang=pose.sa??1.4,ax=[Math.cos(ang),Math.sin(ang)],n=[-ax[1],ax[0]];
    const wp=(u,v)=>[ha[0]+ax[0]*u+n[0]*v,ha[1]+ax[1]*u+n[1]*v];
    // These exact blade vertices also define the exported runtime sockets.
    weaponSocketPoints={root:wp(6,-.25),tip:wp(34,-.9)};
    const corners=[wp(6,-2.2),wp(29,-2.2),wp(34,-.9),wp(29,1.7),wp(6,1.7)].map(T);
    weaponBounds={bladeLength:28,minX:Math.min(...corners.map(p=>p[0])),maxX:Math.max(...corners.map(p=>p[0])),minY:Math.min(...corners.map(p=>p[1])),maxY:Math.max(...corners.map(p=>p[1]))};
    const z=options.weaponBehind?-7:ha[2]+2;
    poly([wp(-3,-1.2),wp(4,-1.2),wp(4,1.2),wp(-3,1.2)],'brassD',z);
    line(wp(-2,-1),wp(2,-1),'brass',z+.01);
    poly([wp(3,-3),wp(5,-3.5),wp(6,3),wp(4,3)],'brass',z+.02);
    line(wp(4,-2.5),wp(5,2.2),'brassL',z+.04);
    poly([wp(6,-2.2),wp(29,-2.2),wp(34,-.9),wp(29,1.7),wp(6,1.7)],'steelD',z+.06);
    poly([wp(6,-2.2),wp(29,-2.2),wp(34,-.9),wp(29,0),wp(6,0)],'steel',z+.08);
    line(wp(7,-2),wp(29,-2),'steelL',z+.1);
    line(wp(10,0),wp(23,0),'glow',z+.12);
  }
  if(pose.settle)settleY=-Math.max(...modelPoints.map(p=>T(p)[1]));
  if(weaponBounds){weaponBounds.minY+=settleY;weaponBounds.maxY+=settleY;}
  parts.sort((a,b)=>a.z-b.z).forEach(p=>p.draw());
  r.outline();
  // All footed frames share exactly the same baseline, no auto-trimming or recenter.
  for(let y=PY+1;y<H;y++)r.buf.fill(0,y*W*4,(y+1)*W*4);
  if(options.silhouette)for(let i=0;i<r.buf.length;i+=4)if(r.buf[i+3])r.buf.set(rgb('#b6d0cc'),i);
  const bones=[['hipN','kneeN',8.6],['kneeN','ankleN',8.3],['hipF','kneeF',8.6],['kneeF','ankleF',8.3],['shoulderN','elbowN',7.6],['elbowN','handN',7.4],['shoulderF','elbowF',7.6],['elbowF','handF',7.4]];
  const maxBoneError=Math.max(...bones.map(([a,b,l])=>Math.abs(Math.hypot(...D(J[a],J[b]))-l*S)));
  const maxGeometryY=Math.max(...modelPoints.map(p=>T(p)[1]));
  geometryChecks.push({maxBoneError,maxGeometryY,bladeLength:weaponBounds?.bladeLength,bladeGroundClearance:weaponBounds?-weaponBounds.maxY:null,pose});
  const weaponSocket=weaponSocketPoints?{root:P(weaponSocketPoints.root),tip:P(weaponSocketPoints.tip)}:null;
  return {r,joints:J,weaponBounds,weaponSocket};
}


export { hero, Raster, geometryChecks, W, H, PX, PY };


