import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

export async function requestPermission(
  permissions: Permissions[],
  context: common.UIAbilityContext): Promise<boolean> {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  const result = await atManager.requestPermissionsFromUser(context, permissions);
  return !!result.authResults.length && result.authResults.every(authResults => authResults === 0);
}
