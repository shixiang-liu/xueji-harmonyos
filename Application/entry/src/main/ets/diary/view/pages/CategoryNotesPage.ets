/**
 * @file CategoryNotesPage.ets
 * @description 分类日记列表页面 - 展示指定分类下的所有日记
 * @features
 * - 按分类名称筛选日记
 * - 按时间分组（最近7天/更早）
 * - 支持跳转至日记详情编辑
 */

import { router } from '@kit.ArkUI';
import { NoteItem } from '../../../diary/model/NoteItem';
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil';
import common from '@ohos.app.ability.common';
import window from '@ohos.window';
import { AppColors, AppSizes, AppShadows, getCardShadow, AppGradients, LinearGradient } from '../../../common/utils/AppTheme';
import { normalizeLearningCategory } from '../../utils/LearningCategories';
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab';

@Entry
@Component
struct CategoryNotesPage {
  /** 当前分类下的日记列表 */
  @State categoryNotes: NoteItem[] = [];
  /** 数据加载状态 */
  @State isLoading: boolean = true;
  /** 当前分类名称 */
  @State categoryName: string = '';
  /** 顶部安全区高度 */
  @State topSafeHeight: number = 0;
  /** 底部安全区高度 */
  @State bottomSafeHeight: number = 0;

  /** 组件即将显示时初始化 */
  aboutToAppear() {
    this.setFullScreen();
    // 从路由参数获取分类名称
    const params = router.getParams() as Record<string, Object>;
    if (params && params['categoryName']) {
      this.categoryName = params['categoryName'] as string;
    } else {
      this.categoryName = '其他';
    }
    this.loadCategoryNotes();
  }

  /** 设置全屏显示并获取安全区高度 */
  async setFullScreen() {
    try {
      const windowClass = await window.getLastWindow(getContext(this));
      await windowClass.setWindowLayoutFullScreen(true);
      const avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeHeight = px2vp(avoidArea.topRect.height);
      this.bottomSafeHeight = px2vp(avoidArea.bottomRect.height);
    } catch (e) {
      this.topSafeHeight = 44;
      this.bottomSafeHeight = 34;
    }
  }

  /** 加载当前分类的日记数据 */
  async loadCategoryNotes() {
    try {
      this.isLoading = true;
      const context = getContext() as common.Context;
      const allNotes: NoteItem[] = await PreferencesUtil.loadNotes(context);

      // 按分类名称筛选日记（统一规范化）
      this.categoryNotes = allNotes.filter(note =>
        note && note.id && normalizeLearningCategory(note.category) === this.categoryName
      );

      // 按创建时间降序排列
      this.categoryNotes.sort((a, b) => (b.createTime || 0) - (a.createTime || 0));
      console.info(`加载分类"${this.categoryName}"的日记，数量:`, this.categoryNotes.length);
      this.isLoading = false;
    } catch (error) {
      console.error('加载分类日记失败:', error);
      this.categoryNotes = [];
      this.isLoading = false;
    }
  }

  /** 获取最近7天内的日记 */
  getRecentNotes(): NoteItem[] {
    const sevenDaysAgo = new Date().getTime() - 7 * 24 * 60 * 60 * 1000;
    return this.categoryNotes.filter(item =>
      item && item.id && item.createTime && item.createTime >= sevenDaysAgo
    );
  }

  /** 获取7天前的日记 */
  getOlderNotes(): NoteItem[] {
    const sevenDaysAgo = new Date().getTime() - 7 * 24 * 60 * 60 * 1000;
    return this.categoryNotes.filter(item =>
      item && item.id && item.createTime && item.createTime < sevenDaysAgo
    );
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
      // Safe area top
      Column()
        .width('100%')
        .height(this.topSafeHeight)
        .backgroundColor(AppColors.BG_PRIMARY)

      // Header
      Row() {
        Row() {
          Text('‹')
            .fontSize(28)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Normal)
            .offset({ y: -2 }) // 微调对齐
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius(20)
        .shadow(AppShadows.SHADOW_XS)
        .onClick(() => {
          router.back();
        })
        
        Text(this.categoryName || '分类')
          .fontSize(AppSizes.FONT_XL)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Column().width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppColors.TEXT_HINT)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.categoryNotes.length === 0) {
        Column({ space: 8 }) {
          Text('暂无记录')
            .fontSize(AppSizes.FONT_LG)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text('该分类下还没有内容')
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_HINT)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          if (this.getRecentNotes().length > 0) {
            ListItem() {
              this.TimeSection('最近', this.getRecentNotes())
            }
          }

          if (this.getOlderNotes().length > 0) {
            ListItem() {
              this.TimeSection('更早', this.getOlderNotes())
            }
          }
          
          ListItem() {
            Column().height(this.bottomSafeHeight + 20)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PRIMARY)

      Column() {
        GlobalAskAIFab({ bottomOffset: this.bottomSafeHeight + 40 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 时间分组区块构建器
   * @param title 分组标题
   * @param notes 该分组下的日记列表
   */
  @Builder TimeSection(title: string, notes: NoteItem[]) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(AppSizes.FONT_SM)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.TEXT_HINT)
        .width('100%')
        .margin({ bottom: 4 })

      ForEach(notes.filter(note => note && note.id), (note: NoteItem) => {
        this.NoteCard(note)
      }, (note: NoteItem) => note.id)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  /**
   * 日记卡片构建器
   * @param note 日记数据对象
   */
  @Builder NoteCard(note: NoteItem) {
    Column({ space: 8 }) {
      Row() {
        Text(note.title || '无标题')
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          
        if (note.isFavorite) {
          Text('⭐')
            .fontSize(14)
            .margin({ left: 8 })
        }
      }
      .width('100%')

      if (note.content) {
        Text(note.content)
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .lineHeight(20)
      }

      Row() {
        Text(note.date || '')
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.TEXT_HINT)

        Blank()

        if (note.recordings && note.recordings.length > 0) {
          Row({ space: 4 }) {
            Text('🎙️')
              .fontSize(12)
            Text(`${note.recordings.length}`)
              .fontSize(AppSizes.FONT_XS)
              .fontColor(AppColors.TEXT_SECONDARY)
          }
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .border({ width: 1, color: AppColors.BORDER })
    .shadow(getCardShadow())
    .onClick(() => {
      router.pushUrl({
        url: 'diary/view/pages/DetailPage',
        params: { editNote: JSON.stringify(note) }
      });
    })
  }
}