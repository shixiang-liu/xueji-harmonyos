import { ConfigurationConstant, UIAbility, Want, AbilityConstant, common, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CloudDBService } from '../common/services/CloudDBService';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { AppThemeManager } from '../common/utils/AppTheme';
import { AuthViewModel } from '../auth/viewmodel/AuthViewModel';
import { AskAIStore } from '../common/services/AskAIStore';
import { AvatarStore } from '../common/services/AvatarStore';
// AGConnect SDK 初始化 - 按官方文档要求导入
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/auth-ohos';

const HILOG_DOMAIN = 0x0000;
const TAG = '[EntryAbility]';

// 全局 SDK 初始化状态
let agcInitialized: boolean = false;
let agcInitPromise: Promise<void> | null = null;

/**
 * 等待 AGConnect SDK 初始化完成
 * 可以在应用任何地方调用此函数来确保 SDK 已经就绪
 */
export async function waitForAGCInit(): Promise<void> {
  if (agcInitialized) {
    return;
  }
  if (agcInitPromise) {
    return agcInitPromise;
  }
  // 未初始化且没有正在进行的 promise，返回拒绝
  return Promise.reject(new Error('AGConnect SDK not initialized yet'));
}

/**
 * 检查 AGConnect SDK 是否已初始化
 */
export function isAGCInitialized(): boolean {
  return agcInitialized;
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      const appContext: common.ApplicationContext = this.context.getApplicationContext();
      // 先设置为跟随系统，稍后根据用户设置覆盖
      appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

      // 初始化 PreferencesUtil（用于本地存储）- 先初始化，因为不依赖 AGConnect
      PreferencesUtil.initContext(this.context);
      hilog.info(HILOG_DOMAIN, TAG, 'PreferencesUtil initialized');

      // 加载 AI 历史会话（不阻塞启动）
      AskAIStore.loadFromDisk(this.context).catch((err: BusinessError) => {
        hilog.warn(HILOG_DOMAIN, TAG, 'AskAIStore loadFromDisk failed: %{public}s', JSON.stringify(err));
      });

      // 加载已保存的用户头像（不阻塞启动）
      AvatarStore.load(this.context).catch((err: BusinessError) => {
        hilog.warn(HILOG_DOMAIN, TAG, 'AvatarStore load failed: %{public}s', JSON.stringify(err));
      });

      // 检测是否从复盘提醒通知打开（reflection://launch）
      this.detectReflectionLaunch(want);

      // 初始化 AGConnect SDK（严格按照官方文档要求）
      // 务必保证 resources/rawfile 中包含 agconnect-services.json 文件
      hilog.info(HILOG_DOMAIN, TAG, 'Initializing AGConnect SDK...');
      agcInitPromise = this.initAGConnect(this.context.getApplicationContext());

      // 恢复用户保存的深色模式设置
      this.restoreColorModeFromPreferences(appContext);
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(HILOG_DOMAIN, TAG, 'Failed to initialize. Cause: %{public}s', JSON.stringify(error));
    }
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onCreate');

    agcInitPromise?.then(() => {
      CloudDBService.getInstance().init().then(() => {
        hilog.info(HILOG_DOMAIN, TAG, 'CloudDBService initialized successfully');
      }).catch((err: BusinessError) => {
        hilog.error(HILOG_DOMAIN, TAG, 'CloudDBService init failed: %{public}s', JSON.stringify(err));
      });
    }).catch((err: BusinessError) => {
      hilog.error(HILOG_DOMAIN, TAG, 'AGConnect SDK init failed, required CloudDB sync unavailable: %{public}s', JSON.stringify(err));
    });
  }

  onDestroy(): void {
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  // 应用已运行时点击通知再次进入：onNewWant 会触发
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.detectReflectionLaunch(want);
  }

  // 解析 want.uri，如果是复盘启动 URI，设置 AppStorage 标志
  private detectReflectionLaunch(want: Want): void {
    try {
      const uri = want?.uri || '';
      if (uri && uri.indexOf('reflection') >= 0) {
        AppStorage.setOrCreate('pendingReflectionLaunch', Date.now());
        hilog.info(HILOG_DOMAIN, TAG, 'Reflection launch detected from notification');
      }
    } catch (e) {
      hilog.warn(HILOG_DOMAIN, TAG, 'detectReflectionLaunch error: %{public}s', JSON.stringify(e));
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    hilog.info(HILOG_DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 关键修复：在加载UI前等待AGConnect SDK初始化完成
    // 这能解决 "Auth failed! agconnect sdk not initialized" 的问题
    try {
      hilog.info(HILOG_DOMAIN, TAG, 'Waiting for AGConnect SDK to be ready...');
      await waitForAGCInit();
      hilog.info(HILOG_DOMAIN, TAG, 'AGConnect SDK ready.');
    } catch (err) {
      hilog.error(HILOG_DOMAIN, TAG, 'Wait for AGC init failed: %{public}s', JSON.stringify(err));
      // 继续执行，让后续流程处理（可能会进入离线模式或报错）
    }

    // 检查登录状态，决定跳转页面
    this.checkAutoLoginAndLoad(windowStage);
  }

  // 自动登录检查
  private async checkAutoLoginAndLoad(windowStage: window.WindowStage): Promise<void> {
    try {
      const authViewModel: AuthViewModel = new AuthViewModel();
      const isLoggedIn: boolean = await authViewModel.checkLoginState();

      hilog.info(HILOG_DOMAIN, TAG, 'Login state check result: %{public}s', isLoggedIn ? 'logged in' : 'not logged in');

      // 根据登录状态选择页面（路径需与main_pages.json中一致）
      const targetPage: string = isLoggedIn ? 'diary/view/pages/HomePage' : 'auth/view/pages/LoginPage';

      windowStage.loadContent(targetPage, (err: BusinessError) => {
        if (err.code) {
          hilog.error(HILOG_DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          // 加载失败时回退到登录页
          windowStage.loadContent('auth/view/pages/LoginPage');
          return;
        }
        hilog.info(HILOG_DOMAIN, TAG, 'Succeeded in loading: %{public}s', targetPage);
      });
    } catch (err) {
      hilog.error(HILOG_DOMAIN, TAG, 'Auto login check failed: %{public}s', JSON.stringify(err));
      // 出错时默认进入登录页
      windowStage.loadContent('auth/view/pages/LoginPage');
    }
  }

  // 从 Preferences 恢复用户保存的深色模式设置
  private async restoreColorModeFromPreferences(appContext: common.ApplicationContext): Promise<void> {
    try {
      const savedDarkMode = await PreferencesUtil.get('isDarkMode', false) as boolean;
      hilog.info(HILOG_DOMAIN, TAG, 'Restored isDarkMode from preferences: %{public}s', String(savedDarkMode));

      // 存入 AppStorage 供 UI 组件使用
      AppStorage.setOrCreate('isDarkMode', savedDarkMode);
      AppThemeManager.setIsDarkMode(savedDarkMode);

      // 设置系统颜色模式
      const colorMode = savedDarkMode
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      appContext.setColorMode(colorMode);
      hilog.info(HILOG_DOMAIN, TAG, 'Applied color mode: %{public}s', savedDarkMode ? 'DARK' : 'LIGHT');
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'Failed to restore color mode: %{public}s', JSON.stringify(err));
      // 默认使用浅色模式
      AppStorage.setOrCreate('isDarkMode', false);
    }
  }

  // 监听系统配置变化（包括深浅色模式切换）
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(HILOG_DOMAIN, TAG, 'onConfigurationUpdate: colorMode = %{public}s', String(newConfig.colorMode));
    // 同步更新 AppStorage 中的状态
    const isDark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate('isDarkMode', isDark);
    AppThemeManager.setIsDarkMode(isDark);
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

  // 确保 AGConnect SDK 初始化
  private async initAGConnect(appContext: common.Context): Promise<void> {
    try {
      agconnect.instance().init(appContext);
      agcInitialized = true;
      hilog.info(HILOG_DOMAIN, TAG, 'AGConnect SDK initialized successfully');
    } catch (err) {
      agcInitialized = false;
      throw new Error(`AGConnect SDK initialization failed: ${err}`);
    }
  }
}
