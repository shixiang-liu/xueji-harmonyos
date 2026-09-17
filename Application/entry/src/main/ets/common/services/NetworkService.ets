// ============================================================================
// 网络状态服务 - NetworkService
// ============================================================================
// 功能：检测网络连接状态、监听网络变化
// 用途：混合存储策略中判断是否在线同步
// API：@kit.NetworkKit - connection
// ============================================================================

import { connection } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

// ============================================================================
// 网络类型枚举
// ============================================================================
export enum NetworkType {
  NONE = 'NONE',       // 无网络
  WIFI = 'WIFI',       // WiFi
  CELLULAR = 'CELLULAR', // 蜂窝数据
  OTHER = 'OTHER'      // 其他（以太网、蓝牙等）
}

// ============================================================================
// 网络变化回调类型
// ============================================================================
export type NetworkCallback = (isOnline: boolean, type: NetworkType) => void;

// ============================================================================
// 网络状态服务 - 单例模式
// ============================================================================
export class NetworkService {
  private static instance: NetworkService;
  
  // 网络连接监听器
  private netConnection: connection.NetConnection | null = null;
  
  // 当前在线状态
  private isOnline: boolean = false;
  
  // 当前网络类型
  private networkType: NetworkType = NetworkType.NONE;
  
  // 监听回调列表
  private callbacks: NetworkCallback[] = [];

  private constructor() {
    // 初始化时检测当前网络状态
    this.checkNetworkStatus();
  }

  // ==================== 单例入口 ====================
  public static getInstance(): NetworkService {
    if (!NetworkService.instance) {
      NetworkService.instance = new NetworkService();
    }
    return NetworkService.instance;
  }

  // ==================== 状态查询 ====================

  /**
   * 检测当前网络状态（同步）
   * @returns 是否在线
   */
  public checkNetworkStatus(): boolean {
    try {
      this.isOnline = connection.hasDefaultNetSync();
      if (this.isOnline) {
        this.updateNetworkType();
      } else {
        this.networkType = NetworkType.NONE;
      }
      return this.isOnline;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[NetworkService] checkNetworkStatus failed. Code: ${error.code}`);
      this.isOnline = false;
      this.networkType = NetworkType.NONE;
      return false;
    }
  }

  /**
   * 获取当前在线状态
   */
  public getIsOnline(): boolean {
    return this.isOnline;
  }

  /**
   * 获取当前网络类型
   */
  public getNetworkType(): NetworkType {
    return this.networkType;
  }

  /**
   * 是否为计费网络（蜂窝数据）
   */
  public isMeteredNetwork(): boolean {
    try {
      return connection.isDefaultNetMeteredSync();
    } catch (err) {
      return false;
    }
  }

  // ==================== 网络监听 ====================

  /**
   * 启动网络状态监听
   */
  public startNetworkMonitor(): void {
    if (this.netConnection !== null) {
      console.info('[NetworkService] Monitor already started.');
      return;
    }

    try {
      this.netConnection = connection.createNetConnection();

      // 网络可用事件
      this.netConnection.on('netAvailable', (data: connection.NetHandle) => {
        console.info(`[NetworkService] Network available. netId: ${data.netId}`);
        this.isOnline = true;
        this.updateNetworkType();
        this.notifyCallbacks();
      });

      // 网络丢失事件
      this.netConnection.on('netLost', (data: connection.NetHandle) => {
        console.info(`[NetworkService] Network lost. netId: ${data.netId}`);
        this.isOnline = false;
        this.networkType = NetworkType.NONE;
        this.notifyCallbacks();
      });

      // 网络不可用事件
      this.netConnection.on('netUnavailable', () => {
        console.info('[NetworkService] Network unavailable.');
        this.isOnline = false;
        this.networkType = NetworkType.NONE;
        this.notifyCallbacks();
      });

      // 注册监听
      this.netConnection.register((error: BusinessError) => {
        if (error) {
          console.error(`[NetworkService] Register failed. Code: ${error.code}`);
        } else {
          console.info('[NetworkService] Network monitor started.');
        }
      });
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[NetworkService] startNetworkMonitor failed. Code: ${error.code}`);
    }
  }

  /**
   * 停止网络状态监听
   */
  public stopNetworkMonitor(): void {
    if (this.netConnection === null) {
      return;
    }

    try {
      this.netConnection.unregister((error: BusinessError) => {
        if (error) {
          console.error(`[NetworkService] Unregister failed. Code: ${error.code}`);
        } else {
          console.info('[NetworkService] Network monitor stopped.');
        }
      });
      this.netConnection = null;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[NetworkService] stopNetworkMonitor failed. Code: ${error.code}`);
    }
  }

  // ==================== 回调管理 ====================

  /**
   * 添加网络变化监听回调
   */
  public addCallback(callback: NetworkCallback): void {
    if (!this.callbacks.includes(callback)) {
      this.callbacks.push(callback);
    }
  }

  /**
   * 移除网络变化监听回调
   */
  public removeCallback(callback: NetworkCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  // ==================== 私有方法 ====================

  /**
   * 更新当前网络类型
   */
  private updateNetworkType(): void {
    try {
      const netHandle = connection.getDefaultNetSync();
      if (netHandle.netId === 0) {
        this.networkType = NetworkType.NONE;
        return;
      }

      const caps = connection.getNetCapabilitiesSync(netHandle);
      if (caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI)) {
        this.networkType = NetworkType.WIFI;
      } else if (caps.bearerTypes.includes(connection.NetBearType.BEARER_CELLULAR)) {
        this.networkType = NetworkType.CELLULAR;
      } else {
        this.networkType = NetworkType.OTHER;
      }
    } catch (err) {
      this.networkType = NetworkType.NONE;
    }
  }

  /**
   * 通知所有监听回调
   */
  private notifyCallbacks(): void {
    for (const callback of this.callbacks) {
      try {
        callback(this.isOnline, this.networkType);
      } catch (err) {
        console.error('[NetworkService] Callback error:', err);
      }
    }
  }
}
