
import { AppColors, AppShadows, AppSizes, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconImage } from '../../../common/components/IconImage'

@Component
export struct InsertMenuDialog {
  @Link showMenu: boolean
  @Link showLinkDialog: boolean
  @Link showChecklistDialog: boolean
  
  onInsertImage: () => void = () => {}
  onInsertVideo: () => void = () => {}
  onCapturePhoto: () => void = () => {}

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1D1D1F')
        .opacity(0.25)
        .onClick(() => {
          this.showMenu = false
        })

      Column({ space: 0 }) {
        // 顶部把手
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor(AppColors.DIVIDER_DARK)
          .margin({ top: 12, bottom: 16 })

        // 标题
        Text('插入')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .letterSpacing(0.5)
          .alignSelf(ItemAlign.Start)
          .padding({ left: 24, bottom: 16 })

        // 选项列表 - 使用 svg 图标
        Column({ space: 8 }) {
          // 图片
          this.InsertMenuItemSimple($r('app.media.icon_image'), '从相册选图片', '插入当前光标位置', () => {
             this.onInsertImage()
          })

          // 视频
          this.InsertMenuItemSimple($r('app.media.icon_video'), '从相册选视频', '插入当前光标位置', () => {
             this.onInsertVideo()
          })

          // 拍照
          this.InsertMenuItemSimple($r('app.media.icon_camera'), '拍照', '拍摄学习现场并插入', () => {
             this.onCapturePhoto()
          })

          // 超链接
          this.InsertMenuItemSimple($r('app.media.icon_link'), '链接', '添加网页链接', () => {
             this.showMenu = false
             this.showLinkDialog = true
          })

          // 清单项
          this.InsertMenuItemSimple($r('app.media.icon_checklist'), '清单', '添加待办事项', () => {
             this.showMenu = false
             this.showChecklistDialog = true
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .padding({ bottom: 32 })
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow({ radius: 24, color: '#00000018', offsetY: -4 })
      .position({ y: '40%' })
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }

  @Builder
  InsertMenuItemSimple(iconRes: Resource, title: string, subtitle: string, onClick: () => void) {
    Row({ space: 14 }) {
      // 图标容器
      Column() {
        IconImage({ src: iconRes, iconSize: 22, color: AppColors.TEXT_PRIMARY })
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(AppColors.BG_TERTIARY)
      .borderRadius(12)

      // 文字
      Column({ space: 2 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(12)
          .fontColor(AppColors.TEXT_TERTIARY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 箭头
      Text('›')
        .fontSize(20)
        .fontColor(AppColors.TEXT_HINT)
    }
    .width('100%')
    .padding({
      left: 14,
      right: 14,
      top: 12,
      bottom: 12
    })
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(12)
    .border({ width: 1, color: AppColors.BORDER })
    .onClick(() => {
      onClick()
    })
  }
}

@Component
export struct LinkDialog {
  @Link showDialog: boolean
  @Link title: string
  @Link url: string
  onConfirm: () => void = () => {}

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#1D1D1F')
        .opacity(0.3)
        .onClick(() => {
          this.showDialog = false
        })

      Column({ space: 20 }) {
        Text('插入链接')
          .fontSize(18)
          .fontColor(AppColors.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(0.5)

        Column({ space: 8 }) {
          Text('显示名称')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.title, placeholder: '例如：会议纪要' })
            .height(48)
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .placeholderColor(AppColors.TEXT_HINT)
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .onChange((v: string) => {
              this.title = v
            })
        }

        Column({ space: 8 }) {
          Text('链接地址')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
            .alignSelf(ItemAlign.Start)
          TextInput({ text: this.url, placeholder: 'https://example.com' })
            .height(48)
            .fontSize(15)
            .fontColor(AppColors.TEXT_PRIMARY)
            .placeholderColor(AppColors.TEXT_HINT)
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .onChange((v: string) => {
              this.url = v
            })
        }

        Row({ space: 12 }) {
          Text('取消')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .onClick(() => {
              this.showDialog = false
            })

          Text('插入')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_WHITE)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: '#1D1D1F20',
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              this.onConfirm()
            })
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .width('88%')
      .padding(24)
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius(20)
      .shadow({
        radius: 32,
        color: '#00000020',
        offsetX: 0,
        offsetY: 12
      })
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }
}

@Component
export struct ChecklistDialog {
  @Link showDialog: boolean
  @Link input: string
  onConfirm: () => void = () => {}

  build() {
    Stack() {
      // 毛玻璃遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_DARK)
        .onClick(() => {
          this.showDialog = false
        })

      Column({ space: 20 }) {
        // 标题
        Text('添加清单项')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .letterSpacing(0.5)

        // 输入区域
        TextArea({ text: this.input, placeholder: '输入待办内容，每行一项' })
          .fontSize(15)
          .fontColor(AppColors.TEXT_PRIMARY)
          .placeholderColor(AppColors.TEXT_HINT)
          .backgroundColor(AppColors.BG_TERTIARY)
          .borderRadius(14)
          .padding(16)
          .constraintSize({ minHeight: 100, maxHeight: 160 })
          .onChange((v: string) => {
            this.input = v
          })

        // 按钮组
        Row({ space: 12 }) {
          Text('取消')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .onClick(() => {
              this.showDialog = false
            })

          Text('添加')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_WHITE)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(12)
            .shadow(AppShadows.SHADOW_SM)
            .onClick(() => {
              this.onConfirm()
            })
        }
        .width('100%')
      }
      .width('88%')
      .padding(24)
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius(20)
      .shadow(AppShadows.SHADOW_LG)
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }
}
