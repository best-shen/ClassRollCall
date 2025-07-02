// 文件路径: entry/src/main/ets/pages/RollCallPage.ets
import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { Student } from '../model/Student';
import { Attendance } from '../model/Attendance';
import info from '../../resources/rawfile/schema.json';
import prompt from '@ohos.prompt';

// 用于在UI上展示每个学生及其考勤状态的视图模型
interface AttendanceRecord {
  studentId: string;
  studentName: string;
  status: string; // '到课', '缺勤', '迟到', '早退', '请假'
  isHighlighted?: boolean; // 用于随机点名高亮效果
}

// 从 StudentPage 接收的参数类型
interface RollCallPageParams {
  className: string;
  courseName: string;
  date: string;
  startPeriod: number;
  endPeriod: number;
}

@Entry
@Component
struct RollCallPage {
  // 页面参数
  @State className: string = '加载中...';
  @State courseName: string = '';
  @State date: string = '';
  @State startPeriod: number = 0;
  @State endPeriod: number = 0;

  // 页面状态
  @State attendanceRecords: AttendanceRecord[] = [];
  private readonly attendanceStatusOptions: string[] = ['到课', '缺勤', '迟到', '早退', '请假'];
  private database: Database | null = null;
  private scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as RollCallPageParams;
    if (params) {
      this.className = params.className;
      this.courseName = params.courseName;
      this.date = params.date;
      this.startPeriod = params.startPeriod;
      this.endPeriod = params.endPeriod;
    }

    this.initDatabase();
    await this.fetchStudents();
  }

  initDatabase(): void {
    if (!this.database) {
      this.database = cloud.database({
        zoneName: "RollCallZone",
        objectTypeInfo: info
      });
    }
  }

  async fetchStudents() {
    try {
      const studentCollection: DatabaseCollection<Student> = this.database!.collection(Student);
      const allStudents: Student[] = await studentCollection.query().equalTo('className', this.className).get();
      allStudents.sort((a, b) => (a.getStudentId() as string).localeCompare(b.getStudentId() as string));

      this.attendanceRecords = allStudents.map((student): AttendanceRecord => ({
        studentId: student.getStudentId(),
        studentName: student.getStudentName(),
        status: '到课',
        isHighlighted: false
      }));
    } catch (e) {
      prompt.showToast({ message: '加载学生列表失败' });
      console.error('Fetch students for roll call failed:', JSON.stringify(e));
    }
  }

  async saveAttendance() {
    try {
      const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);

      const sessionId = `${this.className}-${this.courseName}-${this.date}-${this.startPeriod}-${this.endPeriod}`;
      const periodString = `${this.startPeriod}-${this.endPeriod}`;

      const attendanceEntries: Attendance[] = this.attendanceRecords.map(record => {
        const entry = new Attendance();
        entry.setAttendanceId(`${sessionId}-${record.studentId}`);
        entry.setSessionId(sessionId);
        entry.setStudentId(record.studentId);
        entry.setClassName(this.className);
        entry.setCourseName(this.courseName);
        entry.setDate(this.date);
        entry.setPeriod(periodString);
        entry.setStatus(record.status);
        return entry;
      });

      await attendanceCollection.upsert(attendanceEntries);

      prompt.showToast({ message: '点名记录已保存！' });
      router.back();

    } catch (e) {
      prompt.showToast({ message: '保存失败，请稍后重试' });
      console.error('Save attendance failed:', JSON.stringify(e));
    }
  }

  async randomRollCall() {
    if (this.attendanceRecords.length === 0) return;

    this.attendanceRecords.forEach(record => record.isHighlighted = false);
    const randomIndex = Math.floor(Math.random() * this.attendanceRecords.length);
    const selectedStudent = this.attendanceRecords[randomIndex];

    selectedStudent.isHighlighted = true;
    this.attendanceRecords = [...this.attendanceRecords];
    this.scroller.scrollToIndex(randomIndex, true, ScrollAlign.CENTER);

    setTimeout(() => {
      selectedStudent.isHighlighted = false;
      this.attendanceRecords = [...this.attendanceRecords];
    }, 2000);
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button('返回')
          .height(40)
          .backgroundColor('#F5F5F5')
          .fontColor(Color.Black)
          .onClick(() => router.back())

        Text(`${this.courseName} (${this.date})`)
          .fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)

        Button('返回').height(40).opacity(0)
      }
      .width('100%').padding(16).height(56)

      // 学生列表
      List({ scroller: this.scroller, space: 12 }) {
        ForEach(this.attendanceRecords, (item: AttendanceRecord, index: number) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.studentName).fontSize(18).fontWeight(FontWeight.Bold)
                Text(`(${item.studentId})`).fontSize(14).fontColor(Color.Gray).margin({ left: 8 })
              }
              .width('100%').justifyContent(FlexAlign.Start)

              // 【已修复】重构 Radio 的用法
              Row({ space: 10 }) {
                ForEach(this.attendanceStatusOptions, (statusOption: string) => {
                  Row() {
                    // Radio 的 checked 状态直接与数据源绑定
                    Radio({ value: statusOption, group: `statusGroup_${item.studentId}` })
                      .checked(item.status === statusOption)
                        // 通过 onClick 事件来更新数据源
                      .onClick(() => {
                        this.attendanceRecords[index].status = statusOption;
                      })
                    Text(statusOption).fontSize(14)
                  }
                })
              }
              .width('100%').margin({ top: 10 }).justifyContent(FlexAlign.SpaceBetween)
            }
            .padding(16)
            .backgroundColor(item.isHighlighted ? '#FFFACD' : '#F7FBF9')
            .borderRadius(15)
            .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
            .animation({ duration: 300 })
          }
        })
      }
      .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })

      // 底部按钮
      Row({ space: 20 }) {
        Button('随机点名')
          .layoutWeight(1)
          .backgroundColor('#FFFFFF')
          .fontColor(Color.Black)
          .onClick(() => {
            this.randomRollCall();
          })

        Button('完成点名并保存')
          .layoutWeight(1)
          .type(ButtonType.Capsule)
          .onClick(() => {
            this.saveAttendance();
          })
      }
      .width('100%').padding(20)
    }
    .width('100%').height('100%')
    .backgroundColor('#E0EFE8')
  }
}