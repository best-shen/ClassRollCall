import { ConfigurationConstant, UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {initialize} from  "@hw-agconnect/hmcore"
import jsonStr from "../../resources/rawfile/agconnect-services.json"
const HILOG_DOMAIN = 0x0000;
const TAG = '[EntryAbility]';


export default class EntryAbility extends UIAbility {
  onCreate() {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    // 初始化应用配置
    try {
      initialize(this.context,jsonStr)
    }catch (e){
      console.error(JSON.stringify(e))
    }
  }

  onDestroy(): void {
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(HILOG_DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(HILOG_DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
