/**
 * @file LinkWebViewPage.ets
 * @description 学习记录链接预览页
 */

import { common, Want } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import webview from '@ohos.web.webview';
import { AppColors, AppSizes } from '../../../common/utils/AppTheme';

interface PageEndEvent {
  url: string
}

@Entry
@Component
struct LinkWebViewPage {
  @State url: string = '';
  @State title: string = '链接预览';
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State errorMessage: string = '';
  @StorageLink('isDarkMode') isDarkMode: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();
  private errorCheckTimer: number = -1;
  private pageLoaded: boolean = false;

  aboutToAppear(): void {
    this.pageLoaded = false;
    this.hasError = false;
    this.errorMessage = '';
    this.isLoading = true;

    const params = router.getParams() as Record<string, string>;
    if (params && params['url']) {
      this.url = this.normalizeUrl(params['url']);
    } else {
      this.hasError = true;
      this.errorMessage = '未找到链接地址';
      this.isLoading = false;
    }

    if (params && params['title']) {
      this.title = params['title'];
    }
  }

  aboutToDisappear(): void {
    if (this.errorCheckTimer !== -1) {
      clearTimeout(this.errorCheckTimer);
      this.errorCheckTimer = -1;
    }
  }

  private normalizeUrl(url: string): string {
    const trimmedUrl = url.trim();
    if (!trimmedUrl) {
      return '';
    }
    if (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://')) {
      return trimmedUrl;
    }
    return `https://${trimmedUrl}`;
  }

  private async openInBrowser(): Promise<void> {
    if (!this.url) {
      promptAction.showToast({ message: '暂无链接', duration: 2000 });
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: this.url,
        type: 'text/html'
      };
      await context.startAbility(want);
    } catch (err) {
      console.error('[LinkWebViewPage] 打开浏览器失败:', err);
      promptAction.showToast({ message: '无法打开浏览器', duration: 2000 });
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor(AppColors.TEXT_PRIMARY)
          .onClick(() => {
            router.back();
          })

        Blank()

        Text(this.title)
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()

        Text('···')
          .fontSize(20)
          .fontColor(AppColors.TEXT_PRIMARY)
          .onClick(() => {
            this.openInBrowser();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: AppSizes.SPACE_MD, right: AppSizes.SPACE_MD })
      .backgroundColor(this.isDarkMode ? AppColors.BG_DARK_SECONDARY : AppColors.BG_SECONDARY)

      if (this.url) {
        Stack() {
          Web({ src: this.url, controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .imageAccess(true)
            .mixedMode(MixedMode.All)
            .onTitleReceive((event: OnTitleReceiveEvent) => {
              if (event && event.title) {
                this.title = event.title;
                this.isLoading = false;
                this.hasError = false;
              }
            })
            .onPageEnd((event: PageEndEvent) => {
              if (event) {
                this.pageLoaded = true;
                this.isLoading = false;
                this.hasError = false;
                this.errorMessage = '';
                if (this.errorCheckTimer !== -1) {
                  clearTimeout(this.errorCheckTimer);
                  this.errorCheckTimer = -1;
                }
              }
            })
            .onErrorReceive((event: OnErrorReceiveEvent) => {
              if (!event || !event.request || !event.error) {
                return;
              }
              if (event.request.isMainFrame()) {
                const errorCode: number = event.error.getErrorCode();
                const errorInfo: string = event.error.getErrorInfo();
                if (this.errorCheckTimer !== -1) {
                  clearTimeout(this.errorCheckTimer);
                }
                this.errorCheckTimer = setTimeout(() => {
                  if (!this.pageLoaded) {
                    this.isLoading = false;
                    this.hasError = true;
                    this.errorMessage = errorInfo || `页面加载失败 (${errorCode})`;
                  }
                  this.errorCheckTimer = -1;
                }, 2500) as number;
              }
            })
            .onHttpErrorReceive((event: OnHttpErrorReceiveEvent) => {
              if (!event || !event.request || !event.response) {
                return;
              }
              const statusCode: number = event.response.getResponseCode();
              if (event.request.isMainFrame() && statusCode >= 400) {
                this.errorMessage = `HTTP加载错误: ${statusCode}`;
                this.hasError = true;
                this.isLoading = false;
              }
            })

          if (this.isLoading && !this.hasError) {
            Column({ space: 12 }) {
              LoadingProgress()
                .width(40)
                .height(40)
                .color(AppColors.ACCENT)
              Text('正在加载...')
                .fontSize(AppSizes.FONT_MD)
                .fontColor(AppColors.TEXT_SECONDARY)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.isDarkMode ? AppColors.BG_DARK_PRIMARY : AppColors.BG_PRIMARY)
          }

          if (this.hasError) {
            Column({ space: 16 }) {
              Text(this.errorMessage || '页面加载失败')
                .fontSize(AppSizes.FONT_MD)
                .fontColor(AppColors.TEXT_PRIMARY)
                .textAlign(TextAlign.Center)
                .padding({ left: 32, right: 32 })

              Row({ space: 12 }) {
                Button('重试')
                  .fontSize(AppSizes.FONT_SM)
                  .backgroundColor(AppColors.ACCENT)
                  .fontColor('#FFFFFF')
                  .onClick(() => {
                    this.isLoading = true;
                    this.hasError = false;
                    this.errorMessage = '';
                    this.controller.loadUrl(this.url);
                  })

                Button('在浏览器中打开')
                  .fontSize(AppSizes.FONT_SM)
                  .backgroundColor(AppColors.BG_SECONDARY)
                  .fontColor(AppColors.TEXT_PRIMARY)
                  .onClick(() => {
                    this.openInBrowser();
                  })
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.isDarkMode ? AppColors.BG_DARK_PRIMARY : AppColors.BG_PRIMARY)
          }
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        Column({ space: AppSizes.SPACE_MD }) {
          Text('暂无链接')
            .fontSize(AppSizes.FONT_LG)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? AppColors.BG_DARK_PRIMARY : AppColors.BG_PRIMARY)
  }
}
