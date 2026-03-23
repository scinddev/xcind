const http = require("http");

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(
    JSON.stringify({
      status: "ok",
      app: "backend",
      workspace: "dev",
      db: { host: process.env.DB_HOST, port: process.env.DB_PORT },
    })
  );
});

server.listen(3000, () => {
  console.log("Backend API listening on :3000");
});
