// 文件路径: entry/src/main/ets/pages/Index.ets

import router from '@ohos.router';
import cloud, { DatabaseCollection } from '@hw-agconnect/cloud';
import { Database } from '@hw-agconnect/cloud/src/main/ets/database/Database';
import { ClassInfo } from '../model/ClassInfo';
import info from '../../resources/rawfile/schema.json';

@Entry
@Component
struct Index {
  @State classList: ClassInfo[] = [];
  @State message: string = '正在加载...';
  @State isLoading: boolean = false;
  @State showAddDialog: boolean = false;
  @State newClassName: string = '';

  private database: Database | null = null;

  async aboutToAppear(): Promise<void> {
    this.initDatabase();
    await this.queryClasses();
  }

  initDatabase(): void {
    if (!this.database) {
      this.database = cloud.database({
        zoneName: "RollCallZone",
        objectTypeInfo: info
      });
      this.message = '数据库连接成功';
    }
  }

  getCollection(): DatabaseCollection<ClassInfo> {
    if (!this.database) {
      this.initDatabase();
    }
    return this.database!.collection(ClassInfo);
  }

  async queryClasses() {
    this.isLoading = true;
    this.message = '正在刷新...';
    try {
      const result: ClassInfo[] = await this.getCollection().query().get();
      this.classList = result;
      this.message = `刷新成功，共 ${this.classList.length} 个班级`;
    } catch (e) {
      this.message = '数据刷新失败，请检查网络或权限配置';
      console.error('Query classes failed:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async addClass() {
    if (!this.newClassName.trim()) {
      this.message = "班级名称不能为空";
      return;
    }
    try {
      const newClass = new ClassInfo();
      newClass.setClassName(this.newClassName.trim());
      await this.getCollection().upsert(newClass);
      this.showAddDialog = false;
      this.newClassName = '';
      await this.queryClasses();
      this.message = `班级 "${newClass.getClassName()}" 添加成功`;
    } catch (e) {
      this.message = '添加失败，请检查权限或查看日志';
      console.error('Add class failed:', JSON.stringify(e));
    }
  }

  async deleteClass(classInfoToDelete: ClassInfo) {
    try {
      const className = classInfoToDelete.getClassName() as string;
      await this.getCollection().delete(classInfoToDelete);
      await this.queryClasses();
      this.message = `班级 "${className}" 已被删除`;
    } catch (e) {
      this.message = '删除失败，请检查权限或查看日志';
      console.error('Delete class failed:', JSON.stringify(e));
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('班级列表').fontSize(24).fontWeight(FontWeight.Bold)
          Blank()
          Button('新增班级')
            .onClick(() => {
              this.newClassName = '';
              this.showAddDialog = true;
            }).backgroundColor('#4CAF50')
          Button(this.isLoading ? '加载中...' : '刷新')
            .onClick(() => this.queryClasses())
            .enabled(!this.isLoading)
            .margin({ left: 10 })
        }.width('100%').padding(16)

        Text(this.message).fontSize(14).fontColor(Color.Gray).margin({ top: 5, bottom: 10 })

        List({ space: 12 }) {
          ForEach(this.classList, (item: ClassInfo) => {
            ListItem() {
              Row() {
                Text(item.getClassName() as string).fontSize(18).layoutWeight(1)
                Button('删除')
                  .backgroundColor('#FEEEEE')
                  .fontColor(Color.Red)
                  .height(40)
                  .onClick(() => {
                    this.deleteClass(item);
                  })
              }
              .width('100%')
              .padding(16)
              // 【UI优化】卡片背景色修改为更柔和的浅色
              .backgroundColor('#F7FBF9')
              .borderRadius(15)
              .shadow({ radius: 6, color: '#0000001A', offsetX: 2, offsetY: 4 })
            }
            .onClick(() => {
              router.pushUrl({
                url: 'pages/StudentPage',
                params: { className: item.getClassName() }
              });
            })
          })
        }.layoutWeight(1).padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      // 【UI优化】背景色修改为浅绿色
      .backgroundColor('#E0EFE8')

      if (this.showAddDialog) {
        Column() {
          Column() {
            Text('添加新班级').fontSize(20).fontWeight(FontWeight.Bold).margin({ bottom: 20 })
            TextInput({ placeholder: '请输入班级名称', text: this.newClassName })
              .onChange((value: string) => { this.newClassName = value; })
              .height(50).margin({ bottom: 20 })
            Row() {
              Button('取消').onClick(() => { this.showAddDialog = false; }).layoutWeight(1).backgroundColor('#9E9E9E')
              Button('确定').onClick(() => this.addClass()).layoutWeight(1).backgroundColor('#4CAF50').margin({ left: 12 })
            }
          }.padding(24).width('90%').borderRadius(15).backgroundColor(Color.White)
        }.justifyContent(FlexAlign.Center).width('100%').height('100%').backgroundColor('rgba(0,0,0,0.6)')
      }
    }
  }
}