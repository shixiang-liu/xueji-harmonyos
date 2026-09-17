
import { AppColors, AppShadows, AppSizes, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { IconImage } from '../../../common/components/IconImage'
import { DEFAULT_LEARNING_CATEGORIES } from '../../utils/LearningCategories'

/** 分类选择对话框 */
@Component
export struct CategoryPickerDialog {
  @Link showDialog: boolean
  @Link category: string
  @Prop categories: string[] = DEFAULT_LEARNING_CATEGORIES // Default or passed prop

  build() {
    if (this.showDialog) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#1D1D1F')
          .opacity(0.25)
          .onClick(() => {
            this.showDialog = false
          })

        Column({ space: 0 }) {
        // 顶部把手
        Column()
          .width(36)
          .height(4)
          .borderRadius(2)
          .backgroundColor(AppColors.DIVIDER_DARK)
          .margin({ top: 12, bottom: 20 })

        // 标题
        Text('选择分类')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .letterSpacing(0.5)
          .alignSelf(ItemAlign.Start)
          .padding({ left: 24, bottom: 16 })

        // 分类列表
        Column({ space: 8 }) {
          ForEach(this.categories, (cat: string) => {
            Row() {
              Text(cat)
                .fontSize(15)
                .fontWeight(this.category === cat ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.category === cat ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
                .layoutWeight(1)
              if (this.category === cat) {
                Column() {
                  // 自绘对勾图标
                  Path()
                    .width(12)
                    .height(12)
                    .commands(IconPaths.CHECK)
                    .fill(AppColors.TEXT_WHITE)
                }
                .width(24)
                .height(24)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor(AppColors.ACCENT)
                .linearGradient(AppGradients.PRIMARY_BTN)
                .borderRadius(12)
              }
            }
            .width('100%')
            .padding({
              left: 16,
              right: 16,
              top: 14,
              bottom: 14
            })
            .backgroundColor(this.category === cat ? AppColors.BG_SECONDARY : AppColors.BG_TERTIARY)
            .borderRadius(12)
            .onClick(() => {
              this.category = cat
              this.showDialog = false
            })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .padding({ bottom: 32 })
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .shadow(AppShadows.SHADOW_LG)
      .position({ y: '40%' })
      }
      .width('100%')
      .height('100%')
      .zIndex(999)
    }
  }
}

/** 加锁设置对话框 */
@Component
export struct LockDialog {
  @Link showDialog: boolean
  @Link passwordInput: string
  @Link confirmPasswordInput: string
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
        // 图标
        Column() {
          IconImage({ src: $r('app.media.icon_lock'), iconSize: 36, color: AppColors.TEXT_PRIMARY })
        }
        .width(72)
        .height(72)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppColors.BG_TERTIARY)
        .borderRadius(20)
        .alignSelf(ItemAlign.Center)

        Column({ space: 4 }) {
          Text('设置密码')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)

          Text('设置密码后，查看此记录需要输入密码')
            .fontSize(13)
            .fontColor(AppColors.TEXT_TERTIARY)
            .textAlign(TextAlign.Center)
        }

        Column({ space: 8 }) {
          Text('密码 (至少4位)')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '请输入密码' })
            .type(InputType.Password)
            .height(48)
            .fontSize(15)
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .onChange((v: string) => {
              this.passwordInput = v
            })
        }

        Column({ space: 8 }) {
          Text('确认密码')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
            .alignSelf(ItemAlign.Start)
          TextInput({ placeholder: '再次输入密码' })
            .type(InputType.Password)
            .height(48)
            .fontSize(15)
            .backgroundColor(AppColors.BG_TERTIARY)
            .borderRadius(12)
            .onChange((v: string) => {
              this.confirmPasswordInput = v
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

          Text('确定')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_WHITE)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.ACCENT)
            .linearGradient(AppGradients.PRIMARY_BTN)
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

/** 解锁验证对话框 */
@Component
export struct UnlockDialog {
  @Link showDialog: boolean
  @Link passwordInput: string
  onUnlock: () => void = () => {}

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
        // 图标
        Column() {
          IconImage({ src: $r('app.media.icon_unlock'), iconSize: 36, color: AppColors.TEXT_PRIMARY })
        }
        .width(72)
        .height(72)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppColors.BG_TERTIARY)
        .borderRadius(20)
        .alignSelf(ItemAlign.Center)

        Column({ space: 4 }) {
          Text('解锁记录')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .textAlign(TextAlign.Center)

          Text('输入密码以解除锁定')
            .fontSize(13)
            .fontColor(AppColors.TEXT_TERTIARY)
            .textAlign(TextAlign.Center)
        }

        TextInput({ placeholder: '请输入密码' })
          .type(InputType.Password)
          .height(48)
          .fontSize(15)
          .backgroundColor(AppColors.BG_TERTIARY)
          .borderRadius(12)
          .onChange((v: string) => {
            this.passwordInput = v
          })

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

          Text('解锁')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_WHITE)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
            .backgroundColor(AppColors.ACCENT)
            .linearGradient(AppGradients.PRIMARY_BTN)
            .borderRadius(12)
            .shadow({
              radius: 8,
              color: '#1D1D1F20',
              offsetX: 0,
              offsetY: 2
            })
            .onClick(() => {
              this.onUnlock()
            })
        }
        .width('100%')
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
