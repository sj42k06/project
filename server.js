const express = require("express");
const cors = require("cors");
const multer = require("multer");
const path = require("path");

const app = express();

const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(express.static("public"));
app.use("/uploads", express.static("uploads"));

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, "uploads/");
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});

const upload = multer({ storage: storage });

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "login.html"));
});

app.post("/login", (req, res) => {
  const { userid, pwd } = req.body;

  if (userid === "1234" && pwd === "1234") {
    res.redirect("/index.html");
  } else {
    res.send("로그인 실패");
  }
});

app.post("/upload", upload.single("image"), (req, res) => {
  try {
    const description = req.body.description;
    const image = req.file ? req.file.filename : null;

    res.send({
      message: "upload success",
      description,
      image,
    });
  } catch (err) {
    console.error(err);
    res.status(500).send("error");
  }
});

app.listen(PORT, () => {
  console.log(`server running on port ${PORT}`);
});