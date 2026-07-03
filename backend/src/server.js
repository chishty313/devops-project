const app = require('./app');

// Port is configurable via env but defaults to 8080 as the assessment requires.
// Configurable-not-hardcoded means the same image can run elsewhere without a rebuild.
const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT}`);
});
