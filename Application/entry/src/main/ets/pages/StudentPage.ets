// 文件路径: entry/src/main/ets/pages/StudentPage.ets
import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { Student } from '../model/Student';
import info from '../../resources/rawfile/schema.json';
// 【最终修复】步骤1：使用 'import * as' 语法将模块作为命名空间导入。
import * as promptAction from '@ohos.promptAction';

interface StudentPageParams {
  className: string;
}

// 【最终修复】步骤2：手动定义 DatePickerResult 接口。
interface DatePickerResult {
  year: number;
  month: number;
  day: number;
}

@Entry
@Component
struct StudentPage {
  @State currentClassName: string = '加载中...';
  @State studentList: Student[] = [];
  @State message: string = '正在加载...';
  @State isLoading: boolean = false;
  @State showStudentDialog: boolean = false;
  @State isEditing: boolean = false;
  @State studentId: string = '';
  @State studentName: string = '';
  @State originalStudentId: string = '';
  @State showPasteDialog: boolean = false;
  @State pastedCsvText: string = '';
  @State showRollCallDialog: boolean = false;
  @State courseName: string = '';
  @State selectedDate: Date = new Date();
  @State startPeriod: number = 1;
  @State endPeriod: number = 2;

  private periodRange: string[] = Array.from({ length: 11 }, (v: undefined, i: number) => (i + 1).toString());
  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    const params: StudentPageParams = router.getParams() as StudentPageParams;
    if (params && params.className) {
      this.currentClassName = params.className;
    }
    this.initDatabase();
    await this.queryAndFilterStudents();
  }

  initDatabase(): void {
    if (!this.database) {
      this.database = cloud.database({
        zoneName: "RollCallZone",
        objectTypeInfo: info
      });
    }
  }

  getCollection(): DatabaseCollection<Student> {
    if (!this.database) {
      this.initDatabase();
    }
    return this.database!.collection(Student);
  }

  async queryAndFilterStudents() {
    this.isLoading = true;
    this.message = '正在刷新学生列表...';
    try {
      const allStudents: Student[] = await this.getCollection().query().get();
      const filteredList = allStudents.filter(student => (student.getClassName() as string) === this.currentClassName);
      filteredList.sort((a, b) => (a.getStudentId() as string).localeCompare(b.getStudentId() as string));
      this.studentList = filteredList;
      this.message = `共 ${this.studentList.length} 名学生`;
    } catch (e) {
      this.message = '学生列表加载失败';
      console.error('Query students failed:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async importFromPastedText() {
    if (!this.pastedCsvText.trim()) {
      this.message = '粘贴内容不能为空';
      return;
    }
    try {
      this.message = '正在解析文本...';
      const newStudents: Student[] = this.pastedCsvText
        .split(/\r?\n/)
        .map(line => line.trim())
        .filter(line => line)
        .map(line => {
          const columns = line.split(',');
          const studentId = columns[0] ? columns[0].trim() : '';
          const studentName = columns[1] ? columns[1].trim() : '';
          if (studentId && studentName) {
            const student = new Student();
            student.setStudentId(studentId);
            student.setStudentName(studentName);
            student.setClassName(this.currentClassName);
            return student;
          }
          return null;
        })
        .filter(s => s !== null) as Student[];

      if (newStudents.length > 0) {
        this.message = '正在写入数据库...';
        await this.getCollection().upsert(newStudents);
        this.showPasteDialog = false;
        this.pastedCsvText = '';
        await this.queryAndFilterStudents();
        this.message = `成功导入 ${newStudents.length} 名学生！`;
      } else {
        this.message = '未在粘贴内容中找到有效学生数据';
      }
    } catch (e) {
      this.message = '导入失败，请检查文本格式';
      console.error(`Import from text failed:`, JSON.stringify(e));
    }
  }

  async saveStudent() {
    const newStudentId = this.studentId.trim();
    const newStudentName = this.studentName.trim();
    if (!newStudentId || !newStudentName) {
      this.message = "学号和姓名均不能为空";
      return;
    }
    try {
      const existingStudent = this.studentList.find(s => (s.getStudentId() as string) === newStudentId);
      if (this.isEditing) {
        if (existingStudent && (existingStudent.getStudentId() as string) !== this.originalStudentId) {
          this.message = `学号 ${newStudentId} 已被其他学生使用`;
          return;
        }
      } else {
        if (existingStudent) {
          this.message = `学号 ${newStudentId} 已存在，请勿重复添加`;
          return;
        }
      }
      if (this.isEditing && this.originalStudentId !== newStudentId) {
        const oldStudent = new Student();
        oldStudent.setStudentId(this.originalStudentId);
        await this.getCollection().delete(oldStudent);
      }
      const studentToSave = new Student();
      studentToSave.setStudentId(newStudentId);
      studentToSave.setStudentName(newStudentName);
      studentToSave.setClassName(this.currentClassName);
      await this.getCollection().upsert(studentToSave);
      this.showStudentDialog = false;
      await this.queryAndFilterStudents();
      this.message = `学生 "${newStudentName}" 已保存`;
    } catch (e) {
      this.message = '保存失败，请稍后重试';
      console.error('Save student failed:', JSON.stringify(e));
    }
  }

  async deleteStudent(studentToDelete: Student) {
    try {
      const studentName = studentToDelete.getStudentName() as string;
      await this.getCollection().delete(studentToDelete);
      await this.queryAndFilterStudents();
      this.message = `学生 "${studentName}" 已被删除`;
    } catch (e) {
      this.message = '删除失败';
      console.error('Delete student failed:', JSON.stringify(e));
    }
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Button('返回')
            .height(40)
            .onClick(() => router.back())
            .backgroundColor('#F5F5F5')
            .fontColor(Color.Black)
          Blank()
          Text(this.currentClassName).fontSize(24).fontWeight(FontWeight.Bold)
          Blank()
          Button('返回').height(40).opacity(0)
        }
        .width('100%').padding({ left: 16, right: 16 }).height(56)

        Row({ space: 12 }) {
          Button('历史考勤')
            .onClick(() => {
              this.message = '历史考勤功能待开发'
            })
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .fontColor(Color.Black)
          Button('开始点名')
            .onClick(() => {
              this.showRollCallDialog = true;
            })
            .layoutWeight(1)
            .type(ButtonType.Capsule)
          Button('粘贴导入').onClick(() => {
            this.pastedCsvText = '';
            this.showPasteDialog = true;
          })
            .layoutWeight(1)
            .backgroundColor('#FFFFFF')
            .fontColor(Color.Black)
        }.width('100%').padding({ left: 16, right: 16, bottom: 10 })

        Text(this.message).fontSize(14).fontColor(Color.Gray).margin({ bottom: 10 })

        List({ space: 12 }) {
          ForEach(this.studentList, (student: Student) => {
            ListItem() {
              Row() {
                Column() {
                  Text(student.getStudentName() as string).fontSize(18).fontWeight(FontWeight.Bold)
                  Text(student.getStudentId() as string).fontSize(14).fontColor(Color.Gray).margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Button('编辑').onClick(() => {
                  this.isEditing = true;
                  this.studentId = student.getStudentId() as string;
                  this.originalStudentId = student.getStudentId() as string;
                  this.studentName = student.getStudentName() as string;
                  this.showStudentDialog = true;
                }).margin({ right: 8 }).backgroundColor('#E0EFFF').fontColor(Color.Blue)
                Button('删除').fontColor(Color.Red).backgroundColor('#FEEEEE').onClick(() => {
                  this.deleteStudent(student);
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F7FBF9')
              .borderRadius(15)
              .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
            }
          })
        }
        .width('100%')
        .layoutWeight(1).padding({ left: 16, right: 16 })
      }
      .width('100%').height('100%')
      .backgroundColor('#E0EFE8')

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('+').fontSize(24).fontColor(Color.White)
      }
      .width(56).height(56)
      .backgroundColor('#4CAF50')
      .onClick(() => {
        this.isEditing = false;
        this.studentId = '';
        this.studentName = '';
        this.showStudentDialog = true;
      })
      .position({ x: '85%', y: '90%' })

      this.StudentDialog()
      this.PasteImportDialog()
      this.RollCallSetupDialog()
    }
    .width('100%').height('100%')
  }

  @Builder StudentDialog() {
    if (this.showStudentDialog) {
      Column() {
        Column() {
          Text(this.isEditing ? '编辑学生' : '添加新学生').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })
          TextInput({ placeholder: '请输入学号', text: this.studentId })
            .onChange((val) => { this.studentId = val; }).height(50).margin({ bottom: 10 })
          TextInput({ placeholder: '请输入姓名', text: this.studentName })
            .onChange((val) => { this.studentName = val; }).height(50).margin({ bottom: 20 })
          Row() {
            Button('取消').onClick(() => { this.showStudentDialog = false; }).layoutWeight(1).backgroundColor('#9E9E9E')
            Button('确定').onClick(() => this.saveStudent()).layoutWeight(1).backgroundColor('#4CAF50').margin({ left: 12 })
          }
        }.padding(24).width('90%').borderRadius(15).backgroundColor(Color.White)
      }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)')
    }
  }

  @Builder PasteImportDialog() {
    if (this.showPasteDialog) {
      Column() {
        Column() {
          Text('粘贴导入学生名单').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })
          TextArea({ placeholder: '请在此处粘贴CSV文本内容...\n格式: 学号,姓名 (一行一个)', text: this.pastedCsvText })
            .onChange((val: string) => { this.pastedCsvText = val; })
            .height(200)
            .margin({ bottom: 20 })
            .backgroundColor('#F7F7F7')
          Row() {
            Button('取消').onClick(() => { this.showPasteDialog = false; }).layoutWeight(1).backgroundColor('#9E9E9E')
            Button('确认导入').onClick(() => this.importFromPastedText()).layoutWeight(1).backgroundColor('#4CAF50').margin({ left: 12 })
          }
        }.padding(24).width('90%').borderRadius(15).backgroundColor(Color.White)
      }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)')
    }
  }

  @Builder RollCallSetupDialog() {
    if (this.showRollCallDialog) {
      Column() {
        Column() {
          Text('设置点名信息').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })
          TextInput({ placeholder: '请输入课程名称', text: this.courseName })
            .onChange((val) => { this.courseName = val; })
            .height(50).margin({ bottom: 12 })

          Button(this.formatDate(this.selectedDate))
            .width('100%')
            .onClick(async () => {
              try {
                // 【最终修复】步骤3：使用导入的命名空间 promptAction，并调用其 showDatePickerDialog 方法。
                const result: DatePickerResult = await promptAction.showDatePickerDialog({
                  selected: this.selectedDate,
                });
                this.selectedDate = new Date(result.year, result.month, result.day);
              } catch (error) {
                console.error('Date picker dialog was cancelled or failed.', JSON.stringify(error));
              }
            })
            .margin({ bottom: 12 })

          Text('选择节次:').width('100%').textAlign(TextAlign.Start)
          Row({ space: 10 }) {
            TextPicker({ range: this.periodRange, selected: this.startPeriod - 1 })
              .onChange((value: string | string[], index: number | number[]) => {
                this.startPeriod = Number(this.periodRange[index as number]);
              })
            Text('-')
            TextPicker({ range: this.periodRange, selected: this.endPeriod - 1 })
              .onChange((value: string | string[], index: number | number[]) => {
                this.endPeriod = Number(this.periodRange[index as number]);
              })
          }.width('100%')

          Row() {
            Button('取消').onClick(() => { this.showRollCallDialog = false; }).layoutWeight(1).backgroundColor('#9E9E9E')
            Button('开始点名').onClick(() => {
              if (!this.courseName.trim()) {
                this.message = '课程名称不能为空';
                return;
              }
              if (this.startPeriod > this.endPeriod) {
                this.message = '开始节次不能大于结束节次';
                return;
              }
              router.pushUrl({
                url: 'pages/RollCallPage',
                params: {
                  className: this.currentClassName,
                  courseName: this.courseName,
                  date: this.formatDate(this.selectedDate),
                  startPeriod: this.startPeriod,
                  endPeriod: this.endPeriod
                }
              })
              this.showRollCallDialog = false;
            }).layoutWeight(1).backgroundColor('#4CAF50').margin({ left: 12 })
          }.margin({ top: 20 })
        }.padding(24).width('90%').borderRadius(15).backgroundColor(Color.White)
      }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)')
    }
  }
}