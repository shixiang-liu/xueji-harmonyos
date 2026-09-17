import { router } from '@kit.ArkUI'
import { AppColors, AppSizes } from '../utils/AppTheme'
import { IconImage } from './IconImage'

@Component
export struct BackIconButton {
  onBack: () => void = () => {
    router.back()
  }

  build() {
    Column() {
      IconImage({ src: $r('app.media.icon_arrow_back'), iconSize: 22, color: AppColors.TEXT_PRIMARY })
    }
    .width(44)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(AppSizes.RADIUS_MD)
    .backgroundColor(AppColors.BG_SECONDARY)
    .border({ width: 1, color: AppColors.BORDER })
    .onClick(() => this.onBack())
  }
}
