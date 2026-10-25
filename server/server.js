const express = require('express');
const path = require('path');
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'web')));
const members = [
 {id:'MEM-1001',name:'Sanjay Kumar',phone:'9876543210',village:'Patnai',familyId:'FS-1001',role:'Family Head',monthly:500},
 {id:'MEM-1001-01',name:'Rekha Devi',phone:'',village:'Patnai',familyId:'FS-1001',role:'Spouse',monthly:0},
 {id:'MEM-1001-02',name:'Rohit Kumar',phone:'',village:'Patnai',familyId:'FS-1001',role:'Child',monthly:0}
];
const payments = [{id:'SSV-2025-101',memberId:'MEM-1001',amount:500,mode:'UPI',date:'2025-11-10',status:'Paid'}];
app.get('/api/health',(_,res)=>res.json({ok:true,app:'Sanstha Seva'}));
app.get('/api/members',(_,res)=>res.json(members));
app.post('/api/members',(req,res)=>{const m={...req.body,id:req.body.id||'MEM-'+Date.now()};members.push(m);res.status(201).json(m);});
app.get('/api/payments',(_,res)=>res.json(payments));
app.post('/api/payments',(req,res)=>{const p={...req.body,id:'SSV-'+Date.now(),status:'Paid'};payments.unshift(p);res.status(201).json(p);});
// Stripe must be configured with secret keys on the server only. Implement Checkout + verified webhooks before enabling live billing.
app.post('/api/stripe/checkout',(_,res)=>res.status(501).json({error:'Stripe is not configured. Add STRIPE_SECRET_KEY and implement Checkout/webhook verification before live payments.'}));
app.get('*',(req,res)=>res.sendFile(path.join(__dirname,'..','web','index.html')));
const port=process.env.PORT||3000;
app.listen(port,()=>console.log(`Sanstha Seva running on http://localhost:${port}`));
