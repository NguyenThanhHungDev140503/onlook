import { and, eq, isNull } from 'drizzle-orm';

import { env } from '@/env';
import { legacySubscriptions, subscriptions } from '@onlook/db';
import { db } from '@onlook/db/src/client';
import { SubscriptionStatus } from '@onlook/stripe';

interface UserSubscriptionStatus {
    hasActiveSubscription: boolean;
    hasLegacySubscription: boolean;
}

export async function checkUserSubscriptionAccess(
    userId: string,
    userEmail?: string | null,
): Promise<UserSubscriptionStatus> {
    if (env.NODE_ENV === 'development' || env.NEXT_PUBLIC_ENV === 'development') {
        return {
            hasActiveSubscription: true,
            hasLegacySubscription: false,
        };
    }

    const subscription = await db.query.subscriptions.findFirst({
        where: and(
            eq(subscriptions.userId, userId),
            eq(subscriptions.status, SubscriptionStatus.ACTIVE),
        ),
    });

    const legacySubscription = userEmail
        ? await db.query.legacySubscriptions.findFirst({
              where: and(
                  eq(legacySubscriptions.email, userEmail),
                  isNull(legacySubscriptions.redeemAt),
              ),
          })
        : null;

    return {
        hasActiveSubscription: !!subscription,
        hasLegacySubscription: !!legacySubscription,
    };
}
