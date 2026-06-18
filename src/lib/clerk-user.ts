import { currentUser } from '@clerk/nextjs/server';
import { prisma } from '@/lib/prisma';

export async function getRequiredDbUser() {
  const clerkUser = await currentUser();
  if (!clerkUser) return null;

  const email = clerkUser.emailAddresses.find((item) => item.id === clerkUser.primaryEmailAddressId)?.emailAddress
    ?? clerkUser.emailAddresses[0]?.emailAddress
    ?? null;
  const displayName = clerkUser.fullName || clerkUser.username || email?.split('@')[0] || 'Actor';
  const handleBase = clerkUser.username || email?.split('@')[0] || clerkUser.id.slice(-8);
  const handle = handleBase.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 22) || `actor-${clerkUser.id.slice(-6)}`;

  return prisma.user.upsert({
    where: { clerkUserId: clerkUser.id },
    update: {
      email,
      displayName
    },
    create: {
      clerkUserId: clerkUser.id,
      email,
      displayName,
      handle: `${handle}-${clerkUser.id.slice(-6)}`
    }
  });
}
