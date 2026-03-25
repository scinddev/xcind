const http = require("http");

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ status: "ok", app: "advanced" }));
});

server.listen(3000, () => {
  console.log("Listening on :3000");
});
