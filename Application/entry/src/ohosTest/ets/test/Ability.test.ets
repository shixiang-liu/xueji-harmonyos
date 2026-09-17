import { hilog } from '@kit.PerformanceAnalysisKit';
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { mapVerificationCodeErrorMessage } from '../../../main/ets/auth/utils/AuthErrorMessageUtil';
import { DEFAULT_LEARNING_CATEGORIES, normalizeLearningCategory } from '../../../main/ets/diary/utils/LearningCategories';
import { buildLearningDaySummary, formatLearningDayKey } from '../../../main/ets/diary/utils/LearningDaySummary';
import { NoteItem } from '../../../main/ets/diary/model/NoteItem';
import { RecordingItem } from '../../../main/ets/diary/model/RecordingItem';

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    beforeAll(() => {
    })
    beforeEach(() => {
    })
    afterEach(() => {
    })
    afterAll(() => {
    })
    it('assertContain', 0, () => {
      hilog.info(0x0000, 'testTag', '%{public}s', 'it begin');
      let a = 'abc';
      let b = 'b';
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    })
    it('mapVerifyCodeWrongCode', 0, () => {
      expect(mapVerificationCodeErrorMessage(203818130, 'fallback')).assertEqual('验证码错误');
    })
    it('mapVerifyCodeExpiredCode', 0, () => {
      expect(mapVerificationCodeErrorMessage(203818129, 'fallback')).assertEqual('验证码已过期，请重新获取');
    })
    it('mapVerifyCodeAlreadySignedIn', 0, () => {
      expect(mapVerificationCodeErrorMessage(5, 'fallback')).assertEqual('账号状态已刷新，请重新获取验证码后再试');
    })
    it('mapVerifyCodeFallback', 0, () => {
      expect(mapVerificationCodeErrorMessage(999, 'fallback')).assertEqual('fallback');
    })
    it('defaultLearningCategories', 0, () => {
      expect(DEFAULT_LEARNING_CATEGORIES.join('|')).assertEqual('课程|实验|复习|资料|项目|复盘|其他');
    })
    it('normalizeLegacyCategory', 0, () => {
      expect(normalizeLearningCategory('生活')).assertEqual('其他');
      expect(normalizeLearningCategory('工作')).assertEqual('项目');
      expect(normalizeLearningCategory('学习')).assertEqual('课程');
    })
    it('formatLearningDayKey', 0, () => {
      expect(formatLearningDayKey(1714521600000)).assertEqual('2024-05-01');
    })
    it('buildLearningDaySummaryCountsTodayRecords', 0, () => {
      const targetDay = 1714521600000;
      const todayNote = new NoteItem();
      todayNote.id = 'n1';
      todayNote.title = '线性代数复习';
      todayNote.content = '复习矩阵乘法和逆矩阵';
      todayNote.category = '复习';
      todayNote.createTime = targetDay + 3600000;
      todayNote.hasImage = true;
      const recording = new RecordingItem();
      recording.id = 'r1';
      recording.name = '课堂录音';
      recording.audioDuration = 60;
      recording.createTime = targetDay;
      recording.transcription = '老师强调矩阵乘法顺序';
      todayNote.recordings = [recording];

      const otherDayNote = new NoteItem();
      otherDayNote.id = 'n2';
      otherDayNote.title = '昨天记录';
      otherDayNote.category = '课程';
      otherDayNote.createTime = targetDay - 86400000;

      const reflectionNote = new NoteItem();
      reflectionNote.id = 'r2';
      reflectionNote.noteType = 'reflection';
      reflectionNote.category = '复盘';
      reflectionNote.createTime = targetDay + 7200000;

      const summary = buildLearningDaySummary([todayNote, otherDayNote, reflectionNote], targetDay);
      expect(summary.recordCount).assertEqual(1);
      expect(summary.categoryLine).assertEqual('复习 1 条');
      expect(summary.mediaLine).assertEqual('录音 1 条，图片 1 张');
      expect(summary.promptContext.indexOf('线性代数复习') >= 0).assertTrue();
    })
  })
}
