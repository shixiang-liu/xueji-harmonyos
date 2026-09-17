// 媒体全屏预览页 - 图片双指缩放/拖动，视频全屏播放
import { router } from '@kit.ArkUI'
import { AppColors } from '../../../common/utils/AppTheme'
import { IconImage } from '../../../common/components/IconImage'

interface MediaPreviewParams {
  path: string
  type: string  // 'image' | 'video'
}

@Entry
@Component
struct MediaPreviewPage {
  @State path: string = ''
  @State type: string = 'image'
  @State imgScale: number = 1
  @State translateX: number = 0
  @State translateY: number = 0
  @State baseImgScale: number = 1
  @State baseTranslateX: number = 0
  @State baseTranslateY: number = 0

  aboutToAppear() {
    const params = router.getParams() as MediaPreviewParams | null
    if (params) {
      this.path = params.path || ''
      this.type = params.type || 'image'
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 黑色全屏背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      // 媒体内容
      if (this.type === 'video') {
        Column() {
          Video({ src: this.path, controller: new VideoController() })
            .width('100%')
            .height('60%')
            .controls(true)
            .autoPlay(true)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // 图片：支持双指缩放、单指拖动、双击切换尺寸
        Image(this.path)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .scale({ x: this.imgScale, y: this.imgScale })
          .translate({ x: this.translateX, y: this.translateY })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.baseImgScale = this.imgScale
                })
                .onActionUpdate((event: GestureEvent) => {
                  const next = this.baseImgScale * event.scale
                  this.imgScale = Math.max(0.5, Math.min(4, next))
                }),
              PanGesture({ fingers: 1 })
                .onActionStart(() => {
                  this.baseTranslateX = this.translateX
                  this.baseTranslateY = this.translateY
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.translateX = this.baseTranslateX + event.offsetX
                  this.translateY = this.baseTranslateY + event.offsetY
                }),
              TapGesture({ count: 2 })
                .onAction(() => {
                  if (this.imgScale > 1.01) {
                    this.imgScale = 1
                    this.translateX = 0
                    this.translateY = 0
                  } else {
                    this.imgScale = 2
                  }
                })
            )
          )
      }

      // 关闭按钮（右上）
      Column() {
        IconImage({ src: $r('app.media.icon_close'), iconSize: 20, color: '#FFFFFF' })
      }
      .width(44)
      .height(44)
      .margin({ top: 48, right: 20 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(22)
      .backgroundColor('rgba(0, 0, 0, 0.5)')
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.2)' })
      .onClick(() => {
        router.back()
      })
    }
    .width('100%')
    .height('100%')
  }
}
