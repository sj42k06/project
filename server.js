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
        return res.status(500).send("DB 오류");
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
  try {
    const description = req.body.description || "";
    const imagePath = req.file ? req.file.filename : null;

    db.query(
      "INSERT INTO risks (zone_id, user_id, title, description, image_path, risk_level, status) VALUES (?, ?, ?, ?, ?, ?, ?)",
      [1, 1, "위험", description, imagePath, 1, "미조치"],
      (err, result) => {
        if (err) {
          console.error("DB 에러:", err);
          return res.status(500).send("DB 저장 실패");
        }

        res.send("등록 완료");
      }
    );
  } catch (e) {
    console.error("서버 에러:", e);
    res.status(500).send("서버 오류");
  }
});

app.listen(PORT, () => {
  console.log(`server running on port ${PORT}`);
});