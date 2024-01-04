const opts = { stdio: 'inherit', cwd: 'client', shell: true };
require('child_process').execSync('npm run build', opts);
require('fs').cpSync('client/build', 'dist/www', { recursive: true });