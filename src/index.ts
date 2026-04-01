import { registerPlugin } from '@capacitor/core';

import type { CapgoWidgetKitPlugin } from './definitions';

const CapgoWidgetKit = registerPlugin<CapgoWidgetKitPlugin>('CapgoWidgetKit', {
  web: () => import('./web').then((m) => new m.CapgoWidgetKitWeb()),
});

export * from './definitions';
export * from './runtime';
export * from './helpers/workout';
export { CapgoWidgetKit };
