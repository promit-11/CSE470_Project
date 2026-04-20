import app from "./api/app.js";
import env from "./api/config/env.js";

const port = env.port;
app.listen(port, () => {
  console.log(`server running at ${port}`);
});
