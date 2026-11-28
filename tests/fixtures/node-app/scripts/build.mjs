// "Build": copy src/ to dist/, enough to prove the build script runs.
import { cp } from 'node:fs/promises';

await cp('src', 'dist', { recursive: true });
console.log('built dist/');
