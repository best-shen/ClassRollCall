/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2020-2020. All rights reserved.
 * Generated by the CloudDB ObjectType compiler. DO NOT EDIT!
 */

class Student {
    constructor() {
        this.studentId = undefined;
        this.studentName = "";
        this.className = "";
    }

    setStudentId(studentId) {
        this.studentId = studentId;
    }

    getStudentId() {
        return this.studentId;
    }

    setStudentName(studentName) {
        this.studentName = studentName;
    }

    getStudentName() {
        return this.studentName;
    }

    setClassName(className) {
        this.className = className;
    }

    getClassName() {
        return this.className;
    }
}

Student.className = 'Student';

export {Student}