import fs from 'node:fs/promises';
import path from 'node:path';

import { generateWebtoonImage } from '../src/lib/imagegen';

const baseStyle = [
  'Vertical 9:16 polished semi-realistic Korean webtoon panel.',
  'Crisp webtoon line art, cinematic lighting, expressive faces, detailed but readable background.',
  'No speech bubbles, no readable text, no captions, no watermark, no logo.'
].join(' ');

const assets = [
  {
    file: 'moonlit-audit-01.png',
    prompt:
      'A young Korean municipal auditor woman, late 20s, short black hair, beige trench coat, stands alone at midnight in a rain-slick archive hallway, holding a sealed blue evidence envelope. Flickering fluorescent light, locked file cabinets, tense mystery tone.'
  },
  {
    file: 'moonlit-audit-02.png',
    prompt:
      'The same auditor faces a calm Korean night security guard in his early 30s with round glasses and a dark green uniform. He blocks the archive exit with a key ring in hand, but his eyes show he knows more than he says. Rainy window reflections, suspicion.'
  },
  {
    file: 'moonlit-audit-03.png',
    prompt:
      'The auditor and security guard crouch beside an old photocopier in a dark records room as a hidden compartment opens, revealing a memory card and a torn city map. Close dramatic angle, dust in light beams, conspiracy clue.'
  },
  {
    file: 'moonlit-audit-04.png',
    prompt:
      'On a city hall rooftop before dawn, the auditor holds the evidence envelope against the wind while the security guard points to lights across the district. The first sunrise cuts through storm clouds, resolve and danger.'
  },
  {
    file: 'borrowed-tomorrow-01.png',
    prompt:
      'A Korean high school girl, 18, neat ponytail and navy school uniform, wakes on a quiet subway platform at dawn holding a cracked phone that shows tomorrow on the lock screen without readable text. Empty train, surreal calm.'
  },
  {
    file: 'borrowed-tomorrow-02.png',
    prompt:
      'The same girl runs through a crowded school corridor as motion blur surrounds her, trying to stop a cheerful male classmate with silver-rim glasses from opening a classroom door. Urgent time-loop energy.'
  },
  {
    file: 'borrowed-tomorrow-03.png',
    prompt:
      'Inside a sunlit music room, the girl and her classmate discover dozens of sticky notes arranged like a warning map on a piano. They look at each other, realizing someone else knows the loop. Emotional mystery.'
  },
  {
    file: 'borrowed-tomorrow-04.png',
    prompt:
      'At sunset on a pedestrian bridge, the girl lets the cracked phone fall from her hand while her classmate catches her wrist. Warm orange sky, city traffic below, choice between saving one day and telling the truth.'
  },
  {
    file: 'last-delivery-01.png',
    prompt:
      'A Korean delivery rider woman in her early 30s wearing a red rain jacket stops her scooter in a neon alley at night, holding a small black box marked only by a blank silver seal. Cyber-noir Seoul backstreet, rain.'
  },
  {
    file: 'last-delivery-02.png',
    prompt:
      'The delivery rider meets an exhausted Korean office worker in a deserted convenience store. He recognizes the black box and steps back in fear, fluorescent lights, shelves of snacks blurred, thriller mood.'
  },
  {
    file: 'last-delivery-03.png',
    prompt:
      'The rider opens the black box under a bus stop roof and finds a tiny projector casting a holographic family photo without readable text. Rain falls behind her, her tough expression softens with shock.'
  },
  {
    file: 'last-delivery-04.png',
    prompt:
      'At the edge of the Han River before sunrise, the delivery rider and office worker face a sleek black car in the distance. She hides the box behind her back, choosing to protect him, tense heroic composition.'
  }
];

async function main() {
  const outputDir = path.join(process.cwd(), 'public', 'generated');
  await fs.mkdir(outputDir, { recursive: true });

  for (const asset of assets) {
    const outputPath = path.join(outputDir, asset.file);
    try {
      await fs.access(outputPath);
      console.log(`skip ${asset.file}`);
      continue;
    } catch {
      // Generate missing assets only.
    }

    console.log(`generate ${asset.file}`);
    await generateWebtoonImage({
      outputPath,
      prompt: `${baseStyle} ${asset.prompt}`
    });
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
