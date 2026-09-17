
import { AppColors, AppShadows, AppAnimations, AppGradients, AppSizes, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { IconImage } from '../../../common/components/IconImage'
import { router, promptAction } from '@kit.ArkUI'

/** 顶部导航栏 - Premium Swiss Design */
@Component
export struct DiaryTopBar {
  onSave: () => Promise<void> = async () => {}
  onAIAnalysis: () => void = () => {}
  @Prop isLocked: boolean = false
  @Prop categoryLabel: string = '未分类'
  @Prop topSafeHeight: number = 0  // 问题5修复：添加安全区高度prop
  onLockAction: () => void = () => {}
  onCategoryAction: () => void = () => {}

  private displayCategory(): string {
    const label = (this.categoryLabel || '').trim()
    return label.length > 0 ? label : '未分类'
  }

  build() {
    Row() {
      // 返回按钮 - 简洁设计
      Column() {
        // 简化的返回箭头 <
        Text('‹')
          .fontSize(28)
          .fontColor(AppColors.TEXT_PRIMARY)
          .fontWeight(FontWeight.Normal)
      }
      .width(42)
      .height(42)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(12)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(async () => {
        await this.onSave()
        router.back()
      })

      Blank()

      // 分类下拉框
      Row({ space: 8 }) {
        IconImage({ src: $r('app.media.icon_folder'), iconSize: 18, color: AppColors.TEXT_SECONDARY })
        Text(this.displayCategory())
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)
      .height(40)
      .constraintSize({ maxWidth: 112 })
      .padding({ left: 14, right: 14 })
      .borderRadius(12)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .margin({ right: 8 })
      .onClick(() => {
        this.onCategoryAction()
      })

      // 锁按钮
      Column() {
        IconImage({
          src: this.isLocked ? $r('app.media.icon_lock') : $r('app.media.icon_unlock'),
          iconSize: 20,
          color: this.isLocked ? AppColors.ERROR : AppColors.TEXT_PRIMARY
        })
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 8 })
      .borderRadius(12)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(() => {
        this.onLockAction()
      })

      // 完成按钮 - 鲜艳蓝色
      Row({ space: 6 }) {
        // 对勾图标
        Text('✓')
          .fontSize(16)
          .fontColor(AppColors.TEXT_WHITE)
          .fontWeight(FontWeight.Bold)

        Text('完成')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_WHITE)
          .letterSpacing(0.5)
      }
      .height(40)
      .padding({ left: 18, right: 22 })
      .backgroundColor(AppColors.ACCENT) // 使用主题色确保可见性
      .linearGradient(AppGradients.PRIMARY_BTN)
      .borderRadius(12)
      .onClick(async () => {
        // 先保存
        await this.onSave()
        promptAction.showToast({ message: '已保存', duration: 1000 })

        // 立即返回，不阻塞用户
        router.back()
      })
    }
    .width('100%')
    .height(60)
    .padding({ left: 20, right: 20 })
  }
}

/** 工具栏 - Swiss Spa Premium Design */
@Component
export struct DiaryBottomBar {
  @Link showInsertMenu: boolean
  @Link showEmotionPanel: boolean
  @Prop canUndo: boolean
  @Prop canRedo: boolean
  @Prop emotionEmoji: string
  @Prop emotionLabel: string

  onUndo: () => void = () => {}
  onRedo: () => void = () => {}
  onRecord: () => void = () => {}
  
  @BuilderParam centerButton: () => void = this.DefaultCenterButton

  @Builder
  DefaultCenterButton() {
      Stack() {
         Circle()
           .width(48)
           .height(48)
           .fill(AppColors.ACCENT)
           .linearGradient(AppGradients.PRIMARY_BTN)
           .shadow(AppShadows.SHADOW_MD)
         
         IconImage({ src: $r('app.media.icon_mic'), iconSize: 24, color: AppColors.TEXT_WHITE })
      }
      .alignContent(Alignment.Center)
      .onClick(() => this.onRecord())
  }

  build() {
    Row() {
      // 左侧工具组 - 精致统一的胶囊容器
      Row({ space: 0 }) {
        // 插入按钮 - 带优雅图标
        Row() {
          // Plus 图标 - 自绘精致版本
          Stack() {
            Column().width(14).height(2).backgroundColor(AppColors.TEXT_PRIMARY).borderRadius(1)
            Column().width(2).height(14).backgroundColor(AppColors.TEXT_PRIMARY).borderRadius(1)
          }
        }
        .width(40)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showInsertMenu = true
        })

        // 细致分割线
        Column()
          .width(1)
          .height(18)
          .backgroundColor(AppColors.BORDER_LIGHT)

        // 撤销按钮 - 优雅弧形箭头
        Row() {
          this.UndoIcon()
        }
        .width(40)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .opacity(this.canUndo ? 1 : 0.35)
        .onClick(() => {
          if (this.canUndo) {
            this.onUndo()
          }
        })

        // 细致分割线
        Column()
          .width(1)
          .height(18)
          .backgroundColor(AppColors.BORDER_LIGHT)

        // 重做按钮 - 优雅弧形箭头
        Row() {
          this.RedoIcon()
        }
        .width(40)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .opacity(this.canRedo ? 1 : 0.35)
        .onClick(() => {
          if (this.canRedo) {
            this.onRedo()
          }
        })
      }
      .height(36)
      .backgroundColor(AppColors.BG_SECONDARY)
      .borderRadius(18)
      .border({ width: 0.5, color: AppColors.BORDER_LIGHT })
      .shadow(AppShadows.SHADOW_SM)

      Blank()

      // 录音按钮 (可自定义)
      this.centerButton()

      Blank()

      // 右侧工具组
      Row({ space: 8 }) {
        // 情绪按钮 - 优雅胶囊
        Row({ space: 6 }) {
          Text(this.emotionEmoji)
            .fontSize(16)
          Text(this.emotionLabel)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .height(36)
        .padding({ left: 12, right: 14 })
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius(18)
        .border({ width: 0.5, color: AppColors.BORDER_LIGHT })
        .shadow(AppShadows.SHADOW_SM)
        .onClick(() => {
          this.showEmotionPanel = true
        })
      }
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 12,
      bottom: 24
    })
    .backgroundColor(AppColors.BG_PRIMARY)
  }

  @Builder
  UndoIcon() {
    Column() {
      Path()
        .width(18)
        .height(18)
        .commands(IconPaths.UNDO)
        .fill(AppColors.TEXT_PRIMARY)
    }
  }

  @Builder
  RedoIcon() {
    Column() {
      Path()
        .width(18)
        .height(18)
        .commands(IconPaths.REDO)
        .fill(AppColors.TEXT_PRIMARY)
    }
  }
}
