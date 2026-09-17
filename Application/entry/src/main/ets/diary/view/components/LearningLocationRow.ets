import { AppColors, AppSizes } from '../../../common/utils/AppTheme'

@Component
export struct LearningLocationRow {
  @Link locationName: string
  @Link locationAddress: string
  onAddOrUpdate: () => void = () => {}
  onDelete: () => void = () => {}

  build() {
    Row({ space: 10 }) {
      Text('地点')
        .fontSize(AppSizes.FONT_XS)
        .fontColor('#8e8b82')
        .fontWeight(FontWeight.Medium)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#f5f0e8')
        .borderRadius(8)

      Column() {
        if (this.displayText().length > 0) {
          Text(this.displayText())
            .fontSize(AppSizes.FONT_SM)
            .fontColor('#141413')
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text('添加学习地点')
            .fontSize(AppSizes.FONT_SM)
            .fontColor('#cc785c')
            .fontWeight(FontWeight.Medium)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.onAddOrUpdate())

      if (this.displayText().length > 0) {
        Text('移除')
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.ERROR)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(AppColors.ERROR_BG)
          .borderRadius(8)
          .onClick(() => this.onDelete())
      } else {
        Text('添加')
          .fontSize(AppSizes.FONT_XS)
          .fontColor('#ffffff')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#cc785c')
          .borderRadius(8)
          .onClick(() => this.onAddOrUpdate())
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#faf9f5')
    .borderRadius(10)
    .border({ width: 1, color: '#e6dfd8' })
  }

  /**
   * 一行显示：优先 POI 名（"格物楼"），没有 POI 时退化为详细地址。
   * 两者都空就返回空，UI 层展示"添加学习地点"。
   */
  private displayText(): string {
    const name = this.locationName.trim()
    if (name.length > 0) return name
    return this.locationAddress.trim()
  }
}
