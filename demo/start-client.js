const opts = { stdio: 'inherit', cwd: 'client', shell: true };
require('child_process').execSync('npm start', opts);