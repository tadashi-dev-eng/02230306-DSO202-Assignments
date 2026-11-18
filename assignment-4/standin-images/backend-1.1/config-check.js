// Stand-in for the tutor's backend 1.1 "internal refactoring of configuration
// loading". Preloaded with `node -r` before src/server.js. The API is unchanged,
// but start-up now requires APP_ENV - the behaviour Task 7 asks students to
// discover from the container log rather than from the release note.
const allowed = ['dev', 'staging', 'prod'];
const env = process.env.APP_ENV;
if (!env || !allowed.includes(env)) {
  console.error(`[config] FATAL: required environment variable APP_ENV is ${env ? `invalid ("${env}")` : 'not set'}; expected one of: ${allowed.join(', ')}`);
  process.exit(1);
}
console.log(`[config] backend 1.1 configuration loaded (APP_ENV=${env})`);
