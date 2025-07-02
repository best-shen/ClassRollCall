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
  // 【新增】控制自定义弹窗的状态
  @State showCourseDialog: boolean = false;
  @State availableCourses: string[] = [];

  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as HistoryPageParams;
    if (params) { this.className = params.className; }
    this.initDatabase();
    await this.fetchAndProcessHistory();
  }
  onPageShow(): void {
    this.fetchAndProcessHistory();
  }
  initDatabase(): void {
    if (!this.database) { this.database = cloud.database({ zoneName: "RollCallZone", objectTypeInfo: info }); }
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
      for (const record of allRecords) {
        const sessionId: string = record.sessionId;
        if (!groupedBySession.has(sessionId)) { groupedBySession.set(sessionId, []); }
        groupedBySession.get(sessionId)!.push(record);
      }

      const processedSessions: HistorySessionView[] = [];
      // 【已修复】使用 forEach 代替解构赋值的 for...of
      groupedBySession.forEach((records, sessionId) => {
        if (records.length === 0) return;
        const stats: Stats = { arrived: 0, absent: 0, late: 0, leaveEarly: 0, onLeave: 0 };
        for (const record of records) {
          const status: string = record.status;
          switch (status) {
            case '到课': stats.arrived++; break;
            case '缺勤': stats.absent++; break;
            case '迟到': stats.late++; break;
            case '早退': stats.leaveEarly++; break;
            case '请假': stats.onLeave++; break;
          }
        }
        const statsString = `到课:${stats.arrived} | 缺勤:${stats.absent} | 迟到:${stats.late} | 早退:${stats.leaveEarly} | 请假:${stats.onLeave}`;
        const firstRecord = records[0];
        processedSessions.push({
          sessionId: sessionId,
          courseName: firstRecord.courseName,
          date: firstRecord.date,
          period: `第 ${firstRecord.period} 节`,
          stats: stats,
          statsString: statsString
        } as HistorySessionView);
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
    Button('删除').height(40).backgroundColor('#FEEEEE').fontColor(Color.Red)
      .onClick(() => { this.deleteSession(sessionId); })
  }

  // 【已修改】重构为打开自定义弹窗
  showCourseSelectionDialog() {
    const courseNameSet = new Set<string>();
    for (const session of this.historySessions) {
      courseNameSet.add(session.courseName);
    }
    this.availableCourses = Array.from(courseNameSet);

    if (this.availableCourses.length === 0) {
      prompt.showToast({ message: '没有可供统计的课程' });
      return;
    }
    this.showCourseDialog = true;
  }

  // 【新增】处理课程选择的函数
  onCourseSelected(selectedCourse: string) {
    this.showCourseDialog = false;
    router.pushUrl({
      url: 'pages/SummaryPage',
      params: {
        className: this.className,
        courseName: selectedCourse
      }
    });
  }

  // 【新增】自定义课程选择弹窗
  @Builder CourseSelectionDialog() {
    if (this.showCourseDialog) {
      Column() {
        Column() {
          Text('选择要导出的课程').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })
          List({ space: 10 }) {
            ForEach(this.availableCourses, (courseName: string) => {
              ListItem() {
                Text(courseName).fontSize(18).width('100%').textAlign(TextAlign.Center).padding(12)
              }
              .onClick(() => {
                this.onCourseSelected(courseName);
              })
              .backgroundColor('#F7F7F7')
              .borderRadius(10)
            })
          }
          .width('100%')

          Button('取消')
            .width('100%')
            .margin({ top: 20 })
            .onClick(() => { this.showCourseDialog = false; })
            .backgroundColor('#9E9E9E')

        }.padding(24).width('90%').borderRadius(15).backgroundColor(Color.White)
      }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)')
    }
  }

  build() {
    // 【已修改】在根组件上叠加自定义弹窗
    Stack() {
      Column() {
        Row() {
          Button('返回').height(40).backgroundColor('#F5F5F5').fontColor(Color.Black).onClick(() => router.back())
          Text(`${this.className} - 历史考勤`).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
          Button('汇总统计').height(40).backgroundColor('#E0EFFF').fontColor(Color.Blue)
            .onClick(() => {
              this.showCourseSelectionDialog(); // 调用新方法
            })
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
                .onClick(() => {
                  router.pushUrl({ url: 'pages/RollCallDetailPage', params: { sessionId: item.sessionId } });
                })
                this.DeleteButton(item.sessionId)
              }
              .padding(16).backgroundColor('#F7FBF9').borderRadius(15)
              .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
            }
          })
        }
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }
      .width('100%').height('100%')
      .backgroundColor('#E0EFE8')

      // 调用自定义弹窗
      this.CourseSelectionDialog()
    }
  }
}