// 云数据库服务 - 单例模式确保全局只有一个数据库连接
// Required CloudDB sync for 学迹 data: User, Diary, Memory, Goal.
import { cloudDatabase } from '@kit.CloudFoundationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import cloud from '@hw-agconnect/cloud';
import { User } from '../../auth/model/User';
import { Diary } from '../../diary/model/Diary';
import { Memory } from '../../diary/model/Memory';
import { Goal } from '../../diary/model/Goal';
import { waitForAGCInit } from '../../entryability/EntryAbility';

// Zone 名称需要与 AGC 控制台配置一致
const ZONE_NAME = 'SmartStudyZone';

export class CloudDBService {
  private static instance: CloudDBService;
  private databaseZone: cloudDatabase.DatabaseZone | null = null;
  private lastErrorToastAt: number = 0; // 节流：避免频繁弹 Toast
  private isAuthenticated: boolean = false;
  public lastQueryFailed: boolean = false; // 上次查询是否因为网络/服务异常失败

  private constructor() {
  }


  // 将云端错误转为用户可理解的提示，并节流显示
  private notifyCloudError(context: string, error: BusinessError): void {
    const now = Date.now();
    // 3 秒节流，避免连续弹窗
    if (now - this.lastErrorToastAt < 3000) {
      return;
    }
    this.lastErrorToastAt = now;

    // 只在真正需要提示用户时才显示（比如认证失败），其他错误静默处理
    const isAuthError = error?.code === 401 || error?.code === 1100003;
    if (isAuthError) {
      const message = '云端服务连接失败，数据已保存到本地';
      console.warn(`[CloudDB] ${context} failed. Code: ${error?.code}, Message: ${error?.message}`);
      promptAction.showToast({ message, duration: 2000 });
    } else {
      // 其他错误只记录日志，不打扰用户
      console.warn(`[CloudDB] ${context} failed silently. Code: ${error?.code}`);
    }
  }

  // 单例访问入口
  public static getInstance(): CloudDBService {
    if (!CloudDBService.instance) {
      CloudDBService.instance = new CloudDBService();
    }
    return CloudDBService.instance;
  }

  // 延迟初始化 - 在首次使用时才连接数据库，避免启动时阻塞
  public async init(): Promise<void> {
    if (this.databaseZone !== null) {
      return;
    }
    // 先确保匿名登录
    await this.ensureAuthenticated();
    try {
      console.info('[CloudDB] Attempting to get zone: ' + ZONE_NAME);
      // 必须用 zone() 函数获取实例，不能 new
      this.databaseZone = cloudDatabase.zone(ZONE_NAME);
      console.info('[CloudDB] ✅ Init success with zone: ' + ZONE_NAME);
      
      // 测试连接：尝试一个简单查询
      try {
        const testQuery = new cloudDatabase.DatabaseQuery(Diary);
        testQuery.limit(1);
        const testResult = await this.databaseZone.query(testQuery);
        console.info('[CloudDB] ✅ Connection test passed, can query Diary table');
      } catch (testErr) {
        const testError = testErr as BusinessError;
        console.error('[CloudDB] ⚠️ Zone created but query failed: code=' + testError?.code + ', msg=' + testError?.message);
        // 不清空 zone，可能只是表为空
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error('[CloudDB] ❌ Zone init failed: code=' + error?.code + ', msg=' + error?.message);
      
      // 详细诊断
      if (String(error?.code).includes('1100') || String(error?.message).includes('not found')) {
        console.error('[CloudDB] 💡 Zone "' + ZONE_NAME + '" 不存在！请在 AGC 控制台创建此存储区');
      }
      if (String(error?.message).includes('permission') || error?.code === 403) {
        console.error('[CloudDB] 💡 权限不足！请检查 AGC 控制台的云数据库权限设置');
      }
      
      this.notifyCloudError('Init', error);
      this.databaseZone = null;
    }
  }

  // 所有操作前确保连接可用
  private async ensureInitialized(): Promise<cloudDatabase.DatabaseZone> {
    await this.ensureAuthenticated();
    if (this.databaseZone === null) {
      await this.init();
    }
    if (this.databaseZone === null) {
      throw new Error('[CloudDB] Database zone initialization failed');
    }
    return this.databaseZone;
  }

  // 确保 AGC 匿名认证成功
  private async ensureAuthenticated(): Promise<void> {
    if (this.isAuthenticated) {
      return;
    }
    try {
      // 关键修复：在认证前必须等待 AGConnect SDK 初始化完成
      console.info('[CloudDB] Waiting for AGConnect SDK initialization...');
      await waitForAGCInit();
      console.info('[CloudDB] AGConnect SDK ready, proceeding with authentication...');
      
      console.info('[CloudDB] Checking current user...');
      const current = await cloud.auth().getCurrentUser();
      if (current) {
        this.isAuthenticated = true;
        console.info('[CloudDB] Reuse current user, uid=' + current.getUid() + ', isAnonymous=' +
        current.isAnonymous());
        return;
      }
      console.info('[CloudDB] No current user, attempting anonymous login...');
      const result = await cloud.auth().signInAnonymously();
      const user = result?.getUser?.();
      if (user) {
        this.isAuthenticated = true;
        console.info('[CloudDB] Anonymous login success, uid=' + user.getUid());
      } else {
        console.warn('[CloudDB] signInAnonymously returned but no user object');
      }
    } catch (err) {
      const error = err as BusinessError;
      const code = error?.code ?? 'unknown_code';
      const msg = error?.message ?? 'unknown_message';

      // 提供详细的错误诊断
      console.error(`[CloudDB] ❌ Auth failed! code=${code}, message=${msg}`);
      if (code === 1100001 || String(code) === '1100001') {
        console.error('[CloudDB] 💡 AGConnect SDK 未初始化！请确保 EntryAbility.onCreate 中调用了 agconnect.instance().init()');
      } else if (code === 1100003 || String(code) === '1100003') {
        console.error('[CloudDB] 💡 认证服务未启用！请在 AGC 控制台 -> 认证服务 -> 开启"匿名账号"');
      } else if (code === 401 || String(code) === '401') {
        console.error('[CloudDB] 💡 401错误可能原因：1.匿名认证未开启 2.CloudDB Zone未部署 3.权限配置错误');
      }

      this.notifyCloudError('AnonymousAuth', error);
      // 不抛出异常，允许后续操作继续尝试 CloudDB（可能 World 权限足够）
      console.warn('[CloudDB] Auth failed; required CloudDB sync may be unavailable until AGC auth is fixed');
    }
  }

  /* ==================== Diary 日记表 ==================== */

  // upsert 根据主键自动判断插入或更新，比分开写更简洁
  public async upsertDiary(diary: Diary): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.upsert(diary);
      console.info(`[CloudDB] Upsert Diary success. Count: ${result}`);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Upsert Diary', error);
      return 0;
    }
  }

  // 批量同步时使用，避免多次网络请求
  public async upsertDiaries(diaries: Diary[]): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      let count = 0;
      for (const diary of diaries) {
        count += await zone.upsert(diary);
      }
      console.info(`[CloudDB] Upsert Diaries success. Count: ${count}`);
      return count;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Upsert Diaries', error);
      return 0;
    }
  }

  public async deleteDiary(diary: Diary): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.delete(diary);
      console.info(`[CloudDB] Delete Diary success. Count: ${result}`);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Delete Diary', error);
      return 0;
    }
  }

  public async queryAllDiaries(): Promise<Diary[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Diary);
      const result = await zone.query(predicate);
      return result as Diary[];
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Query Diaries', error);
      return [];
    }
  }

  // 日记列表默认按时间倒序，最新的在前
  public async getDiariesByTime(): Promise<Diary[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Diary);
      predicate.orderByDesc('create_time');
      const result = await zone.query(predicate);
      return result as Diary[];
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Get Diaries By Time', error);
      return [];
    }
  }

  public async getDiaryById(id: string): Promise<Diary | null> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Diary);
      predicate.equalTo('id', id);
      const result = await zone.query(predicate);
      if (result.length > 0) {
        return result[0] as Diary;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Get Diary By Id', error);
      return null;
    }
  }

  /* ==================== User 用户表 ==================== */

  public async upsertUser(user: User): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.upsert(user);
      console.info(`[CloudDB] Upsert User success. Count: ${result}`);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Upsert User', error);
      return 0;
    }
  }

  // 通过 uid 查询用户
  public async getUser(uid: string): Promise<User | null> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(User);
      predicate.equalTo('uid', uid);
      const users = await zone.query(predicate);
      if (users.length > 0) {
        return users[0] as User;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Get User', error);
      return null;
    }
  }

  // 通过手机号查询用户（兼容旧数据）
  public async getUserByPhone(phone: string): Promise<User | null> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(User);
      predicate.equalTo('phone', phone);
      const users = await zone.query(predicate);
      console.info(`[CloudDB] getUserByPhone(${phone}) found ${users.length} users`);
      if (users.length > 0) {
        return users[0] as User;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Get User By Phone', error);
      return null;
    }
  }

  // 通过邮箱查询用户（推荐用于登录/注册检查）
  public async getUserByEmail(email: string): Promise<User | null> {
    this.lastQueryFailed = false
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(User);
      predicate.equalTo('email', email);
      const users = await zone.query(predicate);
      console.info(`[CloudDB] getUserByEmail(${email}) found ${users.length} users`);
      if (users.length > 0) {
        return users[0] as User;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      this.lastQueryFailed = true
      this.notifyCloudError('Get User By Email', error);
      return null;
    }
  }

  public async queryAllUsers(): Promise<User[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(User);
      const result = await zone.query(predicate);
      return result as User[];
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Query Users', error);
      return [];
    }
  }

  public async deleteUser(user: User): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.delete(user);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Delete User', error);
      return 0;
    }
  }

  /* ==================== Memory 记忆关键词表 ==================== */
  // 存储用户日记中提取的关键词，用于学习阻碍分析

  public async upsertMemory(memory: Memory): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.upsert(memory);
      console.info(`[CloudDB] Upsert Memory success. Count: ${result}`);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Upsert Memory', error);
      return 0;
    }
  }

  public async queryAllMemories(): Promise<Memory[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Memory);
      const result = await zone.query(predicate);
      return result as Memory[];
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Query Memories', error);
      return [];
    }
  }

  public async getMemoryById(id: string): Promise<Memory | null> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Memory);
      predicate.equalTo('id', id);
      const result = await zone.query(predicate);
      if (result.length > 0) {
        return result[0] as Memory;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[CloudDB] Get Memory failed. Code: ${error.code}, Message: ${error.message}`);
      return null;
    }
  }

  public async deleteMemory(memory: Memory): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.delete(memory);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Delete Memory', error);
      return 0;
    }
  }

  /* ==================== Goal 目标表 ==================== */
  // 学习目标及倒计时功能

  public async upsertGoal(goal: Goal): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.upsert(goal);
      console.info(`[CloudDB] Upsert Goal success. Count: ${result}`);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Upsert Goal', error);
      return 0;
    }
  }

  public async queryAllGoals(): Promise<Goal[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Goal);
      const result = await zone.query(predicate);
      return result as Goal[];
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Query Goals', error);
      return [];
    }
  }

  // 筛选不同状态: 0=未开始, 1=进行中, 2=已完成, 3=已过期
  public async getGoalsByStatus(status: number): Promise<Goal[]> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Goal);
      predicate.equalTo('status', status);
      const result = await zone.query(predicate);
      return result as Goal[];
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[CloudDB] Query Goals by status failed. Code: ${error.code}, Message: ${error.message}`);
      return [];
    }
  }

  public async getGoalById(id: string): Promise<Goal | null> {
    try {
      const zone = await this.ensureInitialized();
      const predicate = new cloudDatabase.DatabaseQuery(Goal);
      predicate.equalTo('id', id);
      const result = await zone.query(predicate);
      if (result.length > 0) {
        return result[0] as Goal;
      }
      return null;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[CloudDB] Get Goal failed. Code: ${error.code}, Message: ${error.message}`);
      return null;
    }
  }

  public async deleteGoal(goal: Goal): Promise<number> {
    try {
      const zone = await this.ensureInitialized();
      const result = await zone.delete(goal);
      return result;
    } catch (err) {
      const error = err as BusinessError;
      this.notifyCloudError('Delete Goal', error);
      return 0;
    }
  }

  /* ==================== 清空所有数据（测试功能） ==================== */
  
  /**
   * 清空当前用户的所有云端数据
   * 警告：此操作不可恢复！
   */
  public async clearAllData(): Promise<void> {
    try {
      const zone = await this.ensureInitialized();
      
      // 清空 Diary 表
      try {
        const diaryPredicate = new cloudDatabase.DatabaseQuery(Diary);
        const diaries = await zone.query(diaryPredicate);
        if (diaries && diaries.length > 0) {
          await zone.delete(diaries as Diary[]);
          console.info(`[CloudDB] 已删除 ${diaries.length} 条日记数据`);
        }
      } catch (err) {
        const error = err as BusinessError;
        console.error('[CloudDB] 删除日记数据失败:', error.message);
      }

      // 清空 Memory 表
      try {
        const memoryPredicate = new cloudDatabase.DatabaseQuery(Memory);
        const memories = await zone.query(memoryPredicate);
        if (memories && memories.length > 0) {
          await zone.delete(memories as Memory[]);
          console.info(`[CloudDB] 已删除 ${memories.length} 条记忆数据`);
        }
      } catch (err) {
        const error = err as BusinessError;
        console.error('[CloudDB] 删除记忆数据失败:', error.message);
      }

      // 清空 Goal 表
      try {
        const goalPredicate = new cloudDatabase.DatabaseQuery(Goal);
        const goals = await zone.query(goalPredicate);
        if (goals && goals.length > 0) {
          await zone.delete(goals as Goal[]);
          console.info(`[CloudDB] 已删除 ${goals.length} 条目标数据`);
        }
      } catch (err) {
        const error = err as BusinessError;
        console.error('[CloudDB] 删除目标数据失败:', error.message);
      }

      // 清空 User 表（最后删除）
      try {
        const userPredicate = new cloudDatabase.DatabaseQuery(User);
        const users = await zone.query(userPredicate);
        if (users && users.length > 0) {
          await zone.delete(users as User[]);
          console.info(`[CloudDB] 已删除 ${users.length} 条用户数据`);
        }
      } catch (err) {
        const error = err as BusinessError;
        console.error('[CloudDB] 删除用户数据失败:', error.message);
      }

      console.info('[CloudDB] ✅ 所有云端数据已清空');
    } catch (err) {
      const error = err as BusinessError;
      console.error('[CloudDB] 清空数据失败:', error.message);
      // 不抛出异常，允许继续执行后续清理操作
    }
  }

}
