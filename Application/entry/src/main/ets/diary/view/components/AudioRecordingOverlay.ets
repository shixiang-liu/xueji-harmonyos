
import { AppColors, AppSizes, AppShadows, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'

@Component
export struct AudioRecordingOverlay {
  @Link isRecording: boolean
  @Link recordingSeconds: number
  @Prop waveHeights: number[] = new Array(8).fill(24) // Default data
  @Prop transcriptionText: string = ''
  
  onStop: () => void = () => {}
  onCancel: () => void = () => {}

  @State private showCancelHint: boolean = false
  @State private pulseScale: number = 1

  build() {
    Stack() {
      // 背景纯色
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.TEXT_PRIMARY)

      // 主内容区
      Column({ space: 0 }) {
        // 顶部取消按钮
        Row() {
          Blank()
          Text('取消')
            .fontSize(16)
            .fontColor(AppColors.TEXT_HINT)
            .padding({
              left: 20,
              right: 20,
              top: 12,
              bottom: 12
            })
            .onClick(() => {
              this.onCancel()
            })
        }
        .width('100%')
        .padding({ top: 50, right: 10 })

        Blank().layoutWeight(1)

        // 中央录音指示区域
        Column({ space: 24 }) {
          // 波形动画 - 现代圆点风格
          Row({ space: 6 }) {
            ForEach(this.waveHeights, (height: number, index: number) => {
              Column()
                .width(4)
                .height(height)
                .borderRadius(2)
                .backgroundColor(AppColors.TEXT_WHITE)
                .animation({ duration: 80, curve: Curve.EaseInOut })
            })
          }
          .height(80)
          .alignItems(VerticalAlign.Center)

          // 录音时长 - 大号数字
          Text(this.formatDuration(this.recordingSeconds))
            .fontSize(64)
            .fontWeight(FontWeight.Lighter)
            .fontColor(AppColors.TEXT_WHITE)
            .letterSpacing(4)

          // 状态提示
          Row({ space: 8 }) {
            Circle()
              .width(10)
              .height(10)
              .fill('#FF3B30')
            Text('录音中')
              .fontSize(15)
              .fontColor('#FFFFFF99')
          }
        }
        .alignItems(HorizontalAlign.Center)

        Blank().height(40)

        // 提示文字
        Column({ space: 8 }) {
          if (this.transcriptionText) {
             Text(this.transcriptionText)
               .fontSize(18)
               .fontWeight(FontWeight.Medium)
               .fontColor(AppColors.TEXT_WHITE)
               .maxLines(4)
               .textOverflow({ overflow: TextOverflow.Ellipsis })
               .textAlign(TextAlign.Center)
          } else {
             Row({ space: 6 }) {
               Text('✨')
                 .fontSize(14)
               Text('语音正在实时转为文字')
                 .fontSize(14)
                 .fontColor('#FFFFFF90')
             }
   
             Text('请查看上方内容区域')
               .fontSize(12)
               .fontColor('#FFFFFF50')
          }
        }
        .padding({ left: 24, right: 24 })

        Blank().layoutWeight(1)

        // 底部控制区
        Column({ space: 20 }) {
          // 停止按钮 - 发光效果
          Stack() {
            // 外圈脉冲
            Circle()
              .width(100)
              .height(100)
              .fill('transparent')
              .stroke(AppColors.ACCENT)
              .strokeWidth(2)
              .scale({ x: this.pulseScale, y: this.pulseScale })
              .opacity(2 - this.pulseScale)

            // 主按钮
            Column() {
              Column()
                .width(24)
                .height(24)
                .borderRadius(4)
                .backgroundColor('#FFFFFF')
            }
            .width(72)
            .height(72)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(36)
            .shadow({
              radius: 20,
              color: AppColors.ACCENT + '60',
              offsetX: 0,
              offsetY: 4
            })
            .onClick(() => {
              this.onStop()
            })
          }

          // 上滑提示
          Text(this.showCancelHint ? '松开取消录音' : '点击停止 · 上滑取消')
            .fontSize(14)
            .fontColor(this.showCancelHint ? '#FF6B6B' : '#FFFFFF60')
        }
        .padding({ bottom: 60 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1000)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Move) {
        if (e.touches.length > 0) {
          const touch = e.touches[0]
          this.showCancelHint = touch.y < 300
        }
      } else if (e.type === TouchType.Up) {
        if (this.showCancelHint) {
          this.onCancel()
        } else {
          // If tap on button, handled by onClick.
          // But if drag ended here? Safe to assume cancel if hinted
        }
        this.showCancelHint = false
      } else if (e.type === TouchType.Cancel) {
        this.onCancel()
        this.showCancelHint = false
      }
    })
    .onAppear(() => {
       this.animatePulse()
    })
  }

  private animatePulse() {
     animateTo({ duration: 1500, iterations: -1, curve: Curve.Linear }, () => {
        this.pulseScale = 1.5
     })
  }

  /** 格式化时长 (秒 -> mm:ss) */
  private formatDuration(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }
}
