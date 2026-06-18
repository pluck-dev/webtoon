import { spawn } from 'node:child_process';
import path from 'node:path';

type GenerateImageInput = {
  prompt: string;
  outputPath: string;
  referenceImages?: string[];
};

export async function generateWebtoonImage({ prompt, outputPath, referenceImages = [] }: GenerateImageInput) {
  const cliPath =
    process.env.GTI_CLI_PATH ??
    path.resolve(process.cwd(), '..', 'god-tibo-imagen', 'src', 'cli', 'generate.js');

  const args = [
    cliPath,
    '--provider',
    'private-codex',
    '--size',
    '1024x1536',
    '--prompt',
    prompt,
    '--output',
    outputPath
  ];

  for (const image of referenceImages) {
    args.push('--image', image);
  }

  return new Promise<{ stdout: string; stderr: string }>((resolve, reject) => {
    const child = spawn(process.execPath, args, {
      cwd: process.cwd(),
      env: process.env,
      windowsHide: true
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += String(chunk);
    });
    child.stderr.on('data', (chunk) => {
      stderr += String(chunk);
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
        return;
      }
      reject(new Error(stderr || `Image generation failed with exit code ${code}`));
    });
  });
}
