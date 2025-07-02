// 文件路径: entry/src/main/ets/pages/SummaryPage.ets
import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { Attendance } from '../model/Attendance';
import { Student } from '../model/Student';
import info from '../../resources/rawfile/schema.json';
import prompt from '@ohos.prompt';

interface SummaryPageParams {
  className: string;
  courseName: string;
}

interface StudentSummaryView {
  studentId: string;
  studentName: string;
  arrived: number;
  total: number;
  attendanceRate: string;
}

@Entry
@Component
struct SummaryPage {
  @State className: string = '';
  @State courseName: string = '';
  @State studentSummaries: StudentSummaryView[] = [];
  @State message: string = '正在统计...';
  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as SummaryPageParams;
    if (params) {
      this.className = params.className;
      this.courseName = params.courseName;
    }
    this.initDatabase();
    await this.fetchAndProcessSummary();
  }
  initDatabase(): void {
    if (!this.database) { this.database = cloud.database({ zoneName: "RollCallZone", objectTypeInfo: info }); }
  }
  async fetchAndProcessSummary() {
    this.message = `正在统计课程 [${this.courseName}] 的考勤数据...`;
    try {
      const attendanceCollection: DatabaseCollection<Attendance> = this.database!.collection(Attendance);
      const studentCollection: DatabaseCollection<Student> = this.database!.collection(Student);
      const attendanceRecords = await attendanceCollection.query()
        .equalTo('className', this.className)
        .equalTo('courseName', this.courseName)
        .get();
      const allStudents = await studentCollection.query().equalTo('className', this.className).get();
      if (allStudents.length === 0) {
        this.message = '该班级下没有学生';
        return;
      }

      // 【已修改】步骤1：计算这门课总共点名了多少次
      const sessionIds = new Set<string>();
      for (const record of attendanceRecords) {
        sessionIds.add(record.sessionId);
      }
      const totalRollCallCount = sessionIds.size;

      const recordsByStudent = new Map<string, Attendance[]>();
      for (const record of attendanceRecords) {
        const studentId: string = record.studentId;
        if (!recordsByStudent.has(studentId)) { recordsByStudent.set(studentId, []); }
        recordsByStudent.get(studentId)!.push(record);
      }

      const summaries: StudentSummaryView[] = [];
      for (const student of allStudents) {
        const studentId: string = student.studentId;
        const studentRecords = recordsByStudent.get(studentId) || [];

        let arrived = 0;
        // 我们不再需要其他计数器，因为出勤率只看“到课”

        for (const record of studentRecords) {
          if (record.status === '到课') {
            arrived++;
          }
        }

        // 【已修改】步骤2：出勤率计算，分母使用总点名次数
        const attendanceRate = totalRollCallCount > 0 ? (arrived / totalRollCallCount * 100).toFixed(2) + '%' : 'N/A';

        summaries.push({
          studentId: studentId,
          studentName: student.studentName,
          arrived: arrived,
          // 【已修改】步骤3：每个学生的“点名次数”都使用同一个总次数
          total: totalRollCallCount,
          attendanceRate: attendanceRate
        } as StudentSummaryView);
      }

      summaries.sort((a, b) => a.studentId.localeCompare(b.studentId));
      this.studentSummaries = summaries;
      this.message = `统计完成，共 ${summaries.length} 名学生。`;
    } catch (e) {
      this.message = '数据统计失败';
      console.error('Fetch summary failed:', JSON.stringify(e));
    }
  }

  @Builder TableHeader() {
    Row() {
      Text('学号').layoutWeight(3).fontWeight(FontWeight.Bold)
      Text('姓名').layoutWeight(2).fontWeight(FontWeight.Bold)
      Text('到课').layoutWeight(1.5).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      Text('点名次数').layoutWeight(2).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      Text('出勤率').layoutWeight(2.5).fontWeight(FontWeight.Bold).textAlign(TextAlign.End)
    }
    .width('100%').padding({ top: 10, bottom: 10, left: 16, right: 16 }).backgroundColor('#F0F0F0')
  }

  build() {
    Column() {
      Row() {
        Button('返回').height(40).backgroundColor('#F5F5F5').fontColor(Color.Black).onClick(() => router.back())
        Text(this.courseName).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Button('返回').height(40).opacity(0)
      }
      .width('100%').padding(16).height(56)
      Text(this.message).fontSize(14).fontColor(Color.Gray).margin({ top: 5, bottom: 10 })
      List({ space: 0 }) {
        ListItem() {
          this.TableHeader()
        }
        ForEach(this.studentSummaries, (item: StudentSummaryView) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.studentId).layoutWeight(3)
                Text(item.studentName).layoutWeight(2)
                Text(item.arrived.toString()).layoutWeight(1.5).textAlign(TextAlign.Center)
                Text(item.total.toString()).layoutWeight(2).textAlign(TextAlign.Center)
                Text(item.attendanceRate).layoutWeight(2.5).textAlign(TextAlign.End)
              }
              .width('100%').padding({ top: 12, bottom: 12, left: 16, right: 16 })
              Divider().strokeWidth(1).color('#EEEEEE')
            }
          }
        })
      }
      .width('100%').layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor('#F7FBF9')
  }
}