import app from "./api/app.js";
import env from "./api/config/env.js";

app.listen(env.port, () => {
    console.log(`Server listening on port ${env.port}`);
});