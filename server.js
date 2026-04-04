const express = require("express");
const cors = require("cors");
const multer = require("multer");
const path = require("path");
const mysql = require("mysql2");

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(express.static(path.join(__dirname, "public")));
app.use("/uploads", express.static("uploads"));

app.get("/", (req, res) => {
  res.redirect("/login.html");
});

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect(err => {
  if (err) {
    console.error("DB 연결 실패:", err);
  } else {
    console.log("DB 연결 성공");
  }
});

app.post("/login", (req, res) => {
  const { userid, pwd } = req.body;

  db.query(
    "SELECT * FROM users WHERE username=? AND password=?",
    [userid, pwd],
    (err, results) => {
      if (err) {
        console.error(err);
        res.send("DB 오류");
        return;
      }

      if (results.length > 0) {
        res.redirect("/index.html");
      } else {
        res.send("로그인 실패");
      }
    }
  );
});

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/");
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + "-" + file.originalname);
  }
});

const upload = multer({ storage: storage });

app.post("/upload", upload.single("image"), (req, res) => {
  const { riskLevel, description } = req.body;
  const imagePath = req.file ? req.file.filename : null;

  db.query(
    "INSERT INTO risks (zone_id, user_id, title, description, image_path, risk_level, status) VALUES (1, 1, '위험', ?, ?, 1, '미조치')",
    [description, imagePath],
    (err, result) => {
      if (err) {
        console.error(err);
        res.send("DB 저장 실패");
        return;
      }

      res.send("등록 완료");
    }
  );
});

app.listen(PORT, () => {
  console.log(`server running on port ${PORT}`);
});