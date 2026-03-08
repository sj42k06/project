const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');
const cors = require('cors');
const multer = require('multer');

const app = express();

app.use(cors());
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.use(express.static(path.join(__dirname, '../frontend/public')));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const upload = multer({ dest: 'uploads/' });

const db = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '',
  database: 'safety'
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/public/login.html'));
});

app.post('/login', (req, res) => {
  const { userid, pwd } = req.body;

  if (userid === '1234' && pwd === '1234') {
    res.redirect('/index.html');
  } else {
    res.send('로그인 실패');
  }
});

app.post('/upload', upload.single('image'), async (req, res) => {

  const description = req.body.description;
  const imagePath = req.file ? req.file.filename : null;

  try {

    await db.query(
      'INSERT INTO risks (description, image_path) VALUES (?, ?)',
      [description, imagePath]
    );

    res.send('등록 완료');

  } catch (err) {

    console.error(err);
    res.status(500).send('DB 오류');

  }

});

app.get('/risks', async (req, res) => {

  const [rows] = await db.query('SELECT * FROM risks');

  res.json(rows);

});

const PORT = 5000;

app.listen(PORT, () => {
  console.log(`server running on port ${PORT}`);
});