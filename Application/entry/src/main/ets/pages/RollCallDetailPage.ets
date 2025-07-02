// 文件路径: entry/src/main/ets/pages/RollCallDetailPage.ets
import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { Attendance } from '../model/Attendance';
import { Student } from '../model/Student';
import info from '../../resources/rawfile/schema.json';
import prompt from '@ohos.prompt';

// 从 HistoryPage 接收的参数类型
interface DetailPageParams {
  sessionId: string;
}

// 用于在UI上展示合并后的学生和考勤信息
interface AttendanceDetailView {
  studentId: string;
  studentName: string;
  status: string;
  // 保存原始的 Attendance 对象，便于更新
  rawAttendance: Attendance;
}

@Entry
@Component
struct RollCallDetailPage {
  @State sessionId: string = '';
  @State attendanceDetails: AttendanceDetailView[] = [];
  @State message: string = '正在加载...';

  private readonly attendanceStatusOptions: string[] = ['到课', '缺勤', '迟到', '早退', '请假'];
  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as DetailPageParams;
    if (params && params.sessionId) {
      this.sessionId = params.sessionId;
    } else {
      this.message = '加载失败，缺少关键信息';
      return;
    }

    this.initDatabase();
    await this.fetchDetails();
  }

  initDatabase(): void {
    if (!this.database) {
      this.database = cloud.database({
        zoneName: "RollCallZone",
        objectTypeInfo: info
      });
    }
  }

  async fetchDetails() {
    this.message = '正在加载详情...';
    try {
      const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);
      const studentCollection: DatabaseCollection<Student> = this.database!.collection(Student);

      const attendanceRecords: Attendance[] = await attendanceCollection.query().equalTo('sessionId', this.sessionId).get();
      if (attendanceRecords.length === 0) {
        this.message = '未找到点名记录';
        return;
      }
      const className = attendanceRecords[0].getClassName();

      const allStudents: Student[] = await studentCollection.query().equalTo('className', className).get();
      const studentNameMap = new Map<string, string>();
      allStudents.forEach(student => {
        studentNameMap.set(student.getStudentId(), student.getStudentName());
      });

      const details: AttendanceDetailView[] = attendanceRecords.map((record): AttendanceDetailView => {
        const studentId = record.getStudentId();
        return {
          studentId: studentId,
          studentName: studentNameMap.get(studentId) || '未知学生',
          status: record.getStatus(),
          rawAttendance: record
        };
      });

      details.sort((a, b) => a.studentId.localeCompare(b.studentId));
      this.attendanceDetails = details;
      this.message = `共 ${details.length} 条记录`;

    } catch (e) {
      this.message = '加载详情失败';
      console.error('Fetch roll call details failed:', JSON.stringify(e));
    }
  }

  private getStatusColor(status: string): ResourceColor {
    switch (status) {
      case '到课':
        return Color.Green;
      case '缺勤':
        return Color.Red;
      case '迟到':
        return Color.Orange;
      case '早退':
        return '#9370DB'; // 紫色
      case '请假':
        return Color.Blue;
      default:
        return Color.Black;
    }
  }

  async showStatusMenu(detailView: AttendanceDetailView) {
    try {
      const result = await prompt.showActionMenu({
        title: `修改 ${detailView.studentName} 的状态`,
        buttons: [
          { text: this.attendanceStatusOptions[0], color: '#007DFF' },
          { text: this.attendanceStatusOptions[1], color: '#007DFF' },
          { text: this.attendanceStatusOptions[2], color: '#007DFF' },
          { text: this.attendanceStatusOptions[3], color: '#007DFF' },
          { text: this.attendanceStatusOptions[4], color: '#007DFF' }
        ]
      });

      const newStatus = this.attendanceStatusOptions[result.index];
      if (newStatus && newStatus !== detailView.status) {
        const recordToUpdate = detailView.rawAttendance;
        recordToUpdate.setStatus(newStatus);

        const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);
        await attendanceCollection.upsert(recordToUpdate);

        prompt.showToast({ message: '状态更新成功' });
        await this.fetchDetails();
      }
    } catch (err) {
      console.info(`Action menu cancelled, error: ${JSON.stringify(err)}`);
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回').height(40).backgroundColor('#F5F5F5').fontColor(Color.Black).onClick(() => router.back())
        Text('点名详情').fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button('返回').height(40).opacity(0)
      }
      .width('100%').padding(16).height(56)

      Text(this.message).fontSize(14).fontColor(Color.Gray).margin({ top: 5, bottom: 10 })

      List({ space: 12 }) {
        ForEach(this.attendanceDetails, (item: AttendanceDetailView) => {
          // 【已修复】将 .onClick 移动到 ListItem 的尾随闭包之后
          ListItem() {
            Row() {
              Column({ space: 4 }) {
                Text(item.studentName).fontSize(18).fontWeight(FontWeight.Bold)
                Text(item.studentId).fontSize(14).fontColor(Color.Gray)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(item.status)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getStatusColor(item.status))
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F7FBF9')
            .borderRadius(15)
            .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
          }
          .onClick(() => {
            this.showStatusMenu(item);
          })
        })
      }
      .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
    }
    .width('100%').height('100%')
    .backgroundColor('#E0EFE8')
  }
}