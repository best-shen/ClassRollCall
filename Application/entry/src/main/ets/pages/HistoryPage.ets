// 文件路径: entry/src/main/ets/pages/HistoryPage.ets
import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { Attendance } from '../model/Attendance';
import info from '../../resources/rawfile/schema.json';
import prompt from '@ohos.prompt';

interface Stats {
  arrived: number;
  absent: number;
  late: number;
  leaveEarly: number;
  onLeave: number;
}

interface HistorySessionView {
  sessionId: string;
  courseName: string;
  date: string;
  period: string;
  stats: Stats;
  statsString: string;
}

interface HistoryPageParams {
  className: string;
}

@Entry
@Component
struct HistoryPage {
  @State className: string = '加载中...';
  @State historySessions: HistorySessionView[] = [];
  @State message: string = '正在加载...';

  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as HistoryPageParams;
    if (params) {
      this.className = params.className;
    }
    this.initDatabase();
    await this.fetchAndProcessHistory();
  }

  // 【已添加】onPageShow 生命周期回调，确保每次返回页面时都刷新数据
  onPageShow(): void {
    console.info('HistoryPage onPageShow, refreshing data...');
    // 重新获取并处理数据
    this.fetchAndProcessHistory();
  }

  initDatabase(): void {
    if (!this.database) {
      this.database = cloud.database({
        zoneName: "RollCallZone",
        objectTypeInfo: info
      });
    }
  }

  async fetchAndProcessHistory() {
    this.message = '正在加载历史记录...';
    try {
      const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);
      const allRecords: Attendance[] = await attendanceCollection.query().equalTo('className', this.className).get();

      if (allRecords.length === 0) {
        this.message = '暂无历史考勤记录';
        this.historySessions = [];
        return;
      }

      const groupedBySession = new Map<string, Attendance[]>();
      allRecords.forEach(record => {
        const sessionId = record.getSessionId();
        if (!groupedBySession.has(sessionId)) {
          groupedBySession.set(sessionId, []);
        }
        groupedBySession.get(sessionId)!.push(record);
      });

      const processedSessions: HistorySessionView[] = [];
      groupedBySession.forEach((records, sessionId) => {
        if (records.length === 0) return;
        const stats: Stats = { arrived: 0, absent: 0, late: 0, leaveEarly: 0, onLeave: 0 };
        records.forEach(record => {
          const status = record.getStatus();
          switch (status) {
            case '到课': stats.arrived++; break;
            case '缺勤': stats.absent++; break;
            case '迟到': stats.late++; break;
            case '早退': stats.leaveEarly++; break;
            case '请假': stats.onLeave++; break;
          }
        });
        const statsString = `到课:${stats.arrived} | 缺勤:${stats.absent} | 迟到:${stats.late} | 早退:${stats.leaveEarly} | 请假:${stats.onLeave}`;
        const firstRecord = records[0];
        processedSessions.push({
          sessionId: sessionId,
          courseName: firstRecord.getCourseName(),
          date: firstRecord.getDate(),
          period: `第 ${firstRecord.getPeriod()} 节`,
          stats: stats,
          statsString: statsString
        });
      });

      processedSessions.sort((a, b) => b.date.localeCompare(a.date));
      this.historySessions = processedSessions;
      this.message = `共找到 ${this.historySessions.length} 次点名记录`;
    } catch (e) {
      this.message = '加载历史记录失败';
      console.error('Fetch history failed:', JSON.stringify(e));
    }
  }

  async deleteSession(sessionId: string) {
    try {
      const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);
      const recordsToDelete: Attendance[] = await attendanceCollection.query().equalTo('sessionId', sessionId).get();
      if (recordsToDelete.length > 0) {
        await attendanceCollection.delete(recordsToDelete);
        prompt.showToast({ message: '删除成功' });
        await this.fetchAndProcessHistory();
      } else {
        prompt.showToast({ message: '未找到要删除的记录' });
      }
    } catch (e) {
      prompt.showToast({ message: '删除失败' });
      console.error('Delete session failed:', JSON.stringify(e));
    }
  }

  @Builder DeleteButton(sessionId: string) {
    Button('删除')
      .height(40)
      .backgroundColor('#FEEEEE')
      .fontColor(Color.Red)
      .onClick(() => {
        this.deleteSession(sessionId);
      })
  }

  build() {
    Column() {
      Row() {
        Button('返回').height(40).backgroundColor('#F5F5F5').fontColor(Color.Black).onClick(() => router.back())
        Text(`${this.className} - 历史考勤`).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button('返回').height(40).opacity(0)
      }
      .width('100%').padding(16).height(56)

      Text(this.message).fontSize(14).fontColor(Color.Gray).margin({ top: 5, bottom: 10 })

      List({ space: 12 }) {
        ForEach(this.historySessions, (item: HistorySessionView) => {
          ListItem() {
            Row() {
              Column({ space: 8 }) {
                Text(item.courseName).fontSize(18).fontWeight(FontWeight.Bold)
                Text(`${item.date}  ${item.period}`).fontSize(16).fontColor(Color.Gray)
                Divider().strokeWidth(1).color('#EEEEEE').margin({ top: 4, bottom: 4 })
                Text(item.statsString).fontSize(14).fontColor('#666666')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .onClick(() => { // 让左侧区域也可以点击跳转
                router.pushUrl({
                  url: 'pages/RollCallDetailPage',
                  params: { sessionId: item.sessionId }
                });
              })

              this.DeleteButton(item.sessionId)
            }
            .padding(16)
            .backgroundColor('#F7FBF9')
            .borderRadius(15)
            .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
          }
        })
      }
      .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
    }
    .width('100%').height('100%')
    .backgroundColor('#E0EFE8')
  }
}