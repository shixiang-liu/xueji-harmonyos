/**
 * @file CloudDiaryService.ets
 * @description 云端日记服务 - 封装日记的云端CRUD操作
 * 将本地 NoteItem 与云端 Diary 表进行数据转换和同步
 * 
 * 使用 @hw-agconnect/cloud SDK 实现匿名登录认证
 */

import { cloudDatabase } from '@kit.CloudFoundationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Diary } from '../../diary/model/Diary';
import { Goal } from '../../diary/model/Goal';
import { Memory } from '../../diary/model/Memory';
import { NoteItem } from '../../diary/model/NoteItem';
import { connection } from '@kit.NetworkKit';
// AGConnect 云服务 SDK - 提供匿名登录认证
import cloud from '@hw-agconnect/cloud';

const HILOG_DOMAIN = 0x0000;
const TAG = '[CloudDiaryService]';

// 云数据库存储区名称 - 对应 CloudProgram/clouddb/dataentry/d_Diary.json 中的 cloudDBZoneName
// ⚠️ 401 错误说明此 Zone 未在 AGC 控制台正确部署！
// 
// 📋 部署步骤：
// 1. 登录 AGC 控制台: https://developer.huawei.com/consumer/cn/service/josp/agc/index.html
// 2. 选择你的项目 -> 构建 -> 云数据库
// 3. 点击"新增存储区" -> 输入名称: SmartStudyZone
// 4. 导入对象类型: 上传 CloudProgram/clouddb/objecttype/ 下的 JSON 文件
// 5. 设置权限: 所有角色(包括 World) 允许 Read, Upsert, Delete
// 6. 点击"发布"
const ZONE_NAME = 'SmartStudyZone';

/**
 * 云端日记服务类
 * 提供日记的云端存储、查询、删除等功能
 * 使用 AGConnect 匿名登录获取认证后访问 CloudDB
 */
export class CloudDiaryService {
  private static instance: CloudDiaryService;
  private isInitialized: boolean = false;
  private isAuthenticated: boolean = false;
  private currentUserId: string = '';
  // 延迟初始化的 DatabaseZone 实例
  private _diaryZone: cloudDatabase.DatabaseZone | null = null;

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): CloudDiaryService {
    if (!CloudDiaryService.instance) {
      CloudDiaryService.instance = new CloudDiaryService();
    }
    return CloudDiaryService.instance;
  }

  /**
   * 获取 DatabaseZone - 延迟初始化
   * 只有在调用 initialize() 之后才能使用
   */
  private get diaryZone(): cloudDatabase.DatabaseZone {
    if (!this._diaryZone) {
      throw new Error('DatabaseZone not initialized. Call initialize() first.');
    }
    return this._diaryZone;
  }

  /**
   * 检查网络连接状态
   */
  async checkNetworkConnection(): Promise<boolean> {
    try {
      const netHandle = connection.getDefaultNetSync();
      if (netHandle && netHandle.netId !== 0) {
        const netCapabilities = await connection.getNetCapabilities(netHandle);
        hilog.info(HILOG_DOMAIN, TAG, 'Network capabilities: %{public}s', JSON.stringify(netCapabilities));
        return netCapabilities.bearerTypes.length > 0;
      }
      return false;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Check network failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 执行匿名登录认证
   * 使用 @hw-agconnect/cloud SDK 进行匿名登录
   * 注意：必须先在 EntryAbility.onCreate 中调用 agconnect.instance().init() 初始化 SDK
   * @returns 是否认证成功
   */
  private async performAnonymousLogin(): Promise<boolean> {
    if (this.isAuthenticated) {
      hilog.info(HILOG_DOMAIN, TAG, 'Already authenticated, userId: %{public}s', this.currentUserId);
      return true;
    }

    try {
      // 先检查是否已有登录用户
      hilog.info(HILOG_DOMAIN, TAG, 'Checking for existing user...');
      const existingUser = await cloud.auth().getCurrentUser();
      if (existingUser) {
        this.currentUserId = existingUser.getUid();
        this.isAuthenticated = true;
        hilog.info(HILOG_DOMAIN, TAG, 'Found existing user, userId: %{public}s, isAnonymous: %{public}s', 
          this.currentUserId, String(existingUser.isAnonymous()));
        return true;
      }

      // 执行匿名登录
      hilog.info(HILOG_DOMAIN, TAG, 'Performing anonymous login...');
      const signInResult = await cloud.auth().signInAnonymously();
      const user = signInResult.getUser();
      
      this.currentUserId = user.getUid();
      this.isAuthenticated = true;
      
      hilog.info(HILOG_DOMAIN, TAG, '✅ Anonymous login success! userId: %{public}s', this.currentUserId);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      const errorCode = Number(err?.code || 0);
      const errorMsg = String(err?.message || JSON.stringify(error));
      
      // 针对常见错误给出具体提示
      if (errorCode === 1100001) {
        hilog.error(HILOG_DOMAIN, TAG, 
          '❌ AGConnect SDK 未初始化！请确保在 EntryAbility.onCreate 中调用了 agconnect.instance().init()');
      } else if (errorCode === 1100003) {
        hilog.error(HILOG_DOMAIN, TAG, 
          '❌ 认证服务未启用！请在 AGC 控制台启用认证服务并开启匿名账号登录');
      } else {
        hilog.error(HILOG_DOMAIN, TAG, '❌ Anonymous login failed: code=%{public}s, message=%{public}s',
          String(errorCode), errorMsg);
      }
      return false;
    }
  }

  /**
   * 初始化云数据库连接
   * 1. 先执行匿名登录获取认证
   * 2. 然后初始化 DatabaseZone
   */
  async initialize(): Promise<boolean> {
    if (this.isInitialized && this._diaryZone) {
      return true;
    }
    
    try {
      // 先检查网络
      const hasNetwork = await this.checkNetworkConnection();
      hilog.info(HILOG_DOMAIN, TAG, 'Network available: %{public}s', hasNetwork.toString());
      
      if (!hasNetwork) {
        hilog.warn(HILOG_DOMAIN, TAG, 'No network connection, CloudDB may not work');
        // 网络不可用时仍然尝试初始化（可能使用缓存）
      }
      
      // ⭐ 关键步骤：先执行匿名登录获取认证
      hilog.info(HILOG_DOMAIN, TAG, 'Step 1: Performing authentication...');
      const authSuccess = await this.performAnonymousLogin();
      if (!authSuccess) {
        hilog.error(HILOG_DOMAIN, TAG, 'Authentication failed, cannot initialize CloudDB');
        // 认证失败时仍尝试初始化（可能 World 权限足够）
      }
      
      // 初始化 DatabaseZone
      hilog.info(HILOG_DOMAIN, TAG, 'Step 2: Creating DatabaseZone with zone name: %{public}s', ZONE_NAME);
      this._diaryZone = cloudDatabase.zone(ZONE_NAME);
      
      if (!this._diaryZone) {
        hilog.error(HILOG_DOMAIN, TAG, 'Failed to create DatabaseZone');
        return false;
      }
      
      hilog.info(HILOG_DOMAIN, TAG, 'DatabaseZone created successfully');
      
      this.isInitialized = true;
      hilog.info(HILOG_DOMAIN, TAG, '✅ CloudDB initialized successfully with zone: %{public}s, auth: %{public}s', 
        ZONE_NAME, this.isAuthenticated.toString());
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB init failed: code=%{public}s, message=%{public}s', 
        String(err?.code || 'unknown'), 
        String(err?.message || JSON.stringify(error)));
      return false;
    }
  }

  /**
   * 将 NoteItem 转换为云端 Diary 对象
   */
  private noteItemToDiary(note: NoteItem): Diary {
    const diary = new Diary();
    diary.id = note.id;
    // 将完整的 NoteItem 序列化存储到 content 字段
    diary.content = JSON.stringify(note);
    diary.mood = note.learningMoodLabel || note.emotionLabel || '';
    diary.mood_emoji = note.learningMoodEmoji || note.emotionEmoji || '';
    // 如果有录音，取第一个录音的路径
    diary.audio_url = note.recordings && note.recordings.length > 0 
      ? note.recordings[0].audioPath || '' 
      : '';
    diary.create_time = note.createTime || Date.now();
    return diary;
  }

  /**
   * 将云端 Diary 对象转换为 NoteItem
   */
  private diaryToNoteItem(diary: Diary): NoteItem {
    try {
      // 从 content 字段反序列化完整的 NoteItem
      const note: NoteItem = JSON.parse(diary.content || '{}');
      note.learningMoodLabel = note.emotionLabel || note.learningMoodLabel || diary.mood || '';
      note.learningMoodEmoji = note.emotionEmoji || note.learningMoodEmoji || diary.mood_emoji || '';
      return note;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Parse diary content failed: %{public}s', JSON.stringify(error));
      // 如果解析失败，返回基本信息
      const note = new NoteItem();
      note.id = diary.id || '';
      note.content = diary.content || '';
      note.emotionLabel = diary.mood || '';
      note.learningMoodLabel = diary.mood || '';
      note.learningMoodEmoji = diary.mood_emoji || '';
      note.createTime = diary.create_time || 0;
      return note;
    }
  }

  /**
   * 保存或更新日记到云端
   * @param note 日记对象
   */
  async saveNote(note: NoteItem): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    // ========== 调试日志：排查字段长度问题 ==========
    hilog.info(HILOG_DOMAIN, TAG, '🔍 DEBUG note.id: "%{public}s", length: %{public}d', 
      note.id, note.id?.length || 0);
    if (note.recordings && note.recordings.length > 0 && note.recordings[0].audioPath) {
      hilog.info(HILOG_DOMAIN, TAG, '🔍 DEBUG audioPath: "%{public}s", length: %{public}d', 
        note.recordings[0].audioPath, note.recordings[0].audioPath.length);
    }
    const contentStr = JSON.stringify(note);
    hilog.info(HILOG_DOMAIN, TAG, '🔍 DEBUG content JSON length: %{public}d', contentStr.length);
    // ========== 调试日志结束 ==========

    try {
      const diary = this.noteItemToDiary(note);
      await this.diaryZone.upsert(diary);
      hilog.info(HILOG_DOMAIN, TAG, 'Save note success: %{public}s', note.id);
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Save note failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 批量保存日记到云端
   * @param notes 日记列表
   */
  async saveNotes(notes: NoteItem[]): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    // 确保已认证
    if (!this.isAuthenticated) {
      hilog.warn(HILOG_DOMAIN, TAG, 'Not authenticated, attempting re-auth...');
      await this.performAnonymousLogin();
    }

    try {
      hilog.info(HILOG_DOMAIN, TAG, 'Saving %{public}d notes, auth=%{public}s, userId=%{public}s',
        notes.length, String(this.isAuthenticated), this.currentUserId);
      
      const diaries = notes.map(note => this.noteItemToDiary(note));
      for (const diary of diaries) {
        // ========== 调试日志：排查字段长度问题 ==========
        hilog.info(HILOG_DOMAIN, TAG, '🔍 DEBUG diary.id: "%{public}s", length: %{public}d', 
          diary.id, diary.id?.length || 0);
        hilog.info(HILOG_DOMAIN, TAG, '🔍 DEBUG diary.content length: %{public}d, audio_url length: %{public}d', 
          diary.content?.length || 0, diary.audio_url?.length || 0);
        if ((diary.id?.length || 0) > 200) {
          hilog.error(HILOG_DOMAIN, TAG, '❌ ERROR: diary.id exceeds 200 chars! This will cause write failure.');
        }
        // ========== 调试日志结束 ==========
        hilog.info(HILOG_DOMAIN, TAG, 'Upserting diary id=%{public}s', diary.id);
        await this.diaryZone.upsert(diary);
      }
      hilog.info(HILOG_DOMAIN, TAG, 'Save notes success, count: %{public}d', notes.length);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(HILOG_DOMAIN, TAG, 'Save notes failed: code=%{public}s, msg=%{public}s',
        String(err?.code || 'unknown'), String(err?.message || JSON.stringify(error)));
      return false;
    }
  }

  /**
   * 从云端加载所有日记
   * @returns 日记列表
   */
  async loadNotes(): Promise<NoteItem[]> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return [];
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Diary).orderByDesc('create_time');
      const diaries: Diary[] = await this.diaryZone.query(query);
      const notes = diaries.map(diary => this.diaryToNoteItem(diary));
      hilog.info(HILOG_DOMAIN, TAG, 'Load notes success, count: %{public}d', notes.length);
      return notes;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Load notes failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 根据ID加载单个日记
   * @param noteId 日记ID
   */
  async loadNoteById(noteId: string): Promise<NoteItem | null> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return null;
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Diary).equalTo('id', noteId);
      const diaries: Diary[] = await this.diaryZone.query(query);
      if (diaries.length > 0) {
        return this.diaryToNoteItem(diaries[0]);
      }
      return null;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Load note by id failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 按情绪筛选日记
   * @param mood 情绪标签
   */
  async loadNotesByMood(mood: string): Promise<NoteItem[]> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return [];
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Diary)
        .equalTo('mood', mood)
        .orderByDesc('create_time');
      const diaries: Diary[] = await this.diaryZone.query(query);
      return diaries.map(diary => this.diaryToNoteItem(diary));
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Load notes by mood failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 删除单个日记
   * @param noteId 日记ID
   */
  async deleteNote(noteId: string): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    try {
      const diary = new Diary();
      diary.id = noteId;
      await this.diaryZone.delete(diary);
      hilog.info(HILOG_DOMAIN, TAG, 'Delete note success: %{public}s', noteId);
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Delete note failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 删除当前用户的所有日记
   */
  async deleteAllDiaries(): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Diary);
      const diaries: Diary[] = await this.diaryZone.query(query);
      for (const diary of diaries) {
        await this.diaryZone.delete(diary);
      }
      hilog.info(HILOG_DOMAIN, TAG, 'Delete all diaries success, count: %{public}d', diaries.length);
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Delete all diaries failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 删除当前用户的所有目标
   */
  async deleteAllGoals(): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Goal);
      const goals: Goal[] = await this.diaryZone.query(query);
      for (const goal of goals) {
        await this.diaryZone.delete(goal);
      }
      hilog.info(HILOG_DOMAIN, TAG, 'Delete all goals success, count: %{public}d', goals.length);
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Delete all goals failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 删除当前用户的所有记忆
   */
  async deleteAllMemories(): Promise<boolean> {
    if (!this.isInitialized) {
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return false;
    }

    try {
      const query = new cloudDatabase.DatabaseQuery(Memory);
      const memories: Memory[] = await this.diaryZone.query(query);
      for (const memory of memories) {
        await this.diaryZone.delete(memory);
      }
      hilog.info(HILOG_DOMAIN, TAG, 'Delete all memories success, count: %{public}d', memories.length);
      return true;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Delete all memories failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 一键清空所有数据（日记、目标、记忆）
   */
  async clearAllData(): Promise<boolean> {
    try {
      const results = await Promise.all([
        this.deleteAllDiaries(),
        this.deleteAllGoals(),
        this.deleteAllMemories()
      ]);
      const success = results.every(r => r);
      hilog.info(HILOG_DOMAIN, TAG, 'Clear all data %{public}s', success ? 'success' : 'failed');
      return success;
    } catch (error) {
      hilog.error(HILOG_DOMAIN, TAG, 'Clear all data failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 获取云端数据统计（用于验证数据是否同步成功）
   * @returns 各表的数据条数
   */
  async getCloudDataStats(): Promise<CloudDataStats> {
    const stats: CloudDataStats = {
      diaryCount: 0,
      goalCount: 0,
      memoryCount: 0,
      isConnected: false,
      isAuthenticated: this.isAuthenticated,
      userId: this.currentUserId,
      lastSyncTime: Date.now(),
      networkAvailable: false,
      errorMessage: ''
    };

    // 先检查网络
    stats.networkAvailable = await this.checkNetworkConnection();
    if (!stats.networkAvailable) {
      stats.errorMessage = '设备网络不可用';
      hilog.warn(HILOG_DOMAIN, TAG, 'Network not available');
      return stats;
    }

    if (!this.isInitialized) {
      stats.errorMessage = 'CloudDB 未初始化';
      hilog.error(HILOG_DOMAIN, TAG, 'CloudDB not initialized');
      return stats;
    }

    try {
      // 查询日记数量
      const diaryQuery = new cloudDatabase.DatabaseQuery(Diary);
      const diaries: Diary[] = await this.diaryZone.query(diaryQuery);
      stats.diaryCount = diaries.length;

      // 查询目标数量
      const goalQuery = new cloudDatabase.DatabaseQuery(Goal);
      const goals: Goal[] = await this.diaryZone.query(goalQuery);
      stats.goalCount = goals.length;

      // 查询记忆数量
      const memoryQuery = new cloudDatabase.DatabaseQuery(Memory);
      const memories: Memory[] = await this.diaryZone.query(memoryQuery);
      stats.memoryCount = memories.length;

      stats.isConnected = true;
      
      hilog.info(HILOG_DOMAIN, TAG, 
        'Cloud data stats - Diaries: %{public}d, Goals: %{public}d, Memories: %{public}d',
        stats.diaryCount, stats.goalCount, stats.memoryCount);

      return stats;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(HILOG_DOMAIN, TAG, 'Get cloud stats failed: code=%{public}s, message=%{public}s', 
        String(err?.code || 'unknown'),
        String(err?.message || JSON.stringify(error)));
      
      // 解析具体错误
      if (err && err.code) {
        const code = Number(err.code);
        switch (code) {
          case 2300006:
            stats.errorMessage = '网络错误: DNS解析失败，请检查网络';
            break;
          case 1008230001:
            stats.errorMessage = '网络错误: 无法连接服务器';
            break;
          case 1008200002:
            stats.errorMessage = '服务器连接失败';
            break;
          case 1008200003:
            stats.errorMessage = '认证失败: 请先登录华为账号';
            break;
          case 1008210001:
            stats.errorMessage = 'CloudDB Zone不存在，请检查AGC配置';
            break;
          case 1008210002:
            stats.errorMessage = '对象类型不存在，请部署CloudProgram';
            break;
          case 1008231001:
            stats.errorMessage = '权限错误: 需要部署CloudProgram并开通服务';
            break;
          case 1008232001:
            stats.errorMessage = '未登录: 请先登录华为账号';
            break;
          case 1008232002:
            stats.errorMessage = '登录已过期，请重新登录';
            break;
          default:
            stats.errorMessage = `错误码: ${code} - ${err.message || '未知错误'}`;
        }
      } else {
        stats.errorMessage = String(err?.message || '未知错误');
      }
      
      return stats;
    }
  }
}

/**
 * 云端数据统计接口
 */
export interface CloudDataStats {
  diaryCount: number;
  goalCount: number;
  memoryCount: number;
  isConnected: boolean;
  isAuthenticated: boolean;
  userId: string;
  lastSyncTime: number;
  networkAvailable: boolean;
  errorMessage: string;
}
