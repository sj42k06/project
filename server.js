const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');
const app = express();

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(express.static(path.join(__dirname, 'public'),{ index: false })); // public 폴더를 루트(/) 경로로 설정

// 홈 페이지 라우트
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

//로그인
app.post('/login', (req, res) => {
  const { userid, pwd } = req.body;

  if (userid === '1234' && pwd === '1234') {
    res.redirect('/index.html');  
  } else {
    res.redirect('/response-fail.html'); 
  }
});


const PORT = 3000;
app.listen(PORT, () => {
  console.log(`서버 실행 중: http://localhost:${PORT}`);
});
