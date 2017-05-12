---
title: 开启Spring Boot之旅
date: 2017-05-11 17:35:13
tags: [Spring,Boot]
---

# 环境准备

- 一个称手的文本编辑器（例如Vim、Emacs、Sublime Text）或者IDE（Eclipse、Idea Intellij）  
- Java环境（JDK 1.7或以上版本）  
- Maven 3.0+（Eclipse和Idea IntelliJ内置，如果使用IDE并且不使用命令行工具可以不安装）  

# 一个最简单的Web应用
  使用Spring Boot框架可以大大加速Web应用的开发过程，首先在Maven项目依赖中引入spring-boot-starter-web：pom.xml
  ```
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.tianmaying</groupId>
  <artifactId>spring-web-demo</artifactId>
  <version>0.0.1</version>
  <packaging>jar</packaging>

  <name>springBoot-demo</name>
  <description>Demo project for Spring WebMvc</description>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>1.5.2.RELEASE</version>
    <relativePath/>
  </parent>

  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <java.version>1.8</java.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>


</project>
  ```

  ## 创建Application.java 编写Hello World
  ```
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class Application {

    @RequestMapping("/")
    public String greeting() {
        return "Hello World!";
    }

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
  ```

  ## 添加配置文件，SpringBoot的配置文件名默认为application.yml(或者 properties)
```
\#修改默认端口
server:
  port: 8001
```

## 启动
```
spring boot 是通过main函数启动内置的Tomcat服务的，
直接通过maven命令 spring-boot:run来启动服务，除了配置文件外，
其他使用和spring4MVC的注解方式一样操作
```
## 集成thymleaf模板页面
   spring boot 推荐使用 thymeleaf模板作为前端视图
### 在pom文件中添加 依赖
```
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-thymeleaf</artifactId>
</dependency>
```
### 在application文件中添加配置
```
spring:
  thymeleaf:
    prefix: classpath:/templates/  
    suffix: .html  
    mode: HTML5  
    encoding: UTF-8  
    content-type: text/html  
    # 开发环境下关闭cache
    cache： false  
```
### 测试代码，html页面和Controller
```
import java.util.Map;  
import org.springframework.stereotype.Controller;  
import org.springframework.web.bind.annotation.RequestMapping; 
@Controller   
publicclass TemplateController {  
    /**  
     * 返回html模板.  
     */  
    @RequestMapping("/helloHtml")  
    public String helloHtml(Map<String,Object> map){  
       map.put("hello","from TemplateController.helloHtml");  
       return"/helloHtml";  
    }  
} 
```

```
<!DOCTYPE html>  
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:th="http://www.thymeleaf.org"  
      xmlns:sec="http://www.thymeleaf.org/thymeleaf-extras-springsecurity3">  
    <head>  
        <title>Hello World!</title>  
    </head>  
    <body>  
        <h1 th:inline="text">Hello.v.2</h1>  
        <p th:text="${hello}"></p>  
    </body>  
</html>
```
