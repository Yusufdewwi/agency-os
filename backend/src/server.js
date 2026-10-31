import app from './app.js';
import { env } from './config/env.js';

const server = app.listen(env.PORT, () => {
  console.log(`Agency OS API listening on ${env.API_BASE_URL}`);
});

function shutdown(signal) {
  console.log(`${signal} received. Closing server...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
