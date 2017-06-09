---
title: '通过consul实现服务发现，feignclient实现REST接口封装，从server到服务发现，客户端封装和web应用调用的一个demo'
date: 2017-05-25 18:24:49
tags:
---
  本篇内容主要介绍了spring cloud 的使用中用到的一些技术和对应的实现，包括spring boot项目搭建，consul的配置，server服务的结构和结构的具体内容，feignclient的创建和调用。
  <!-- more -->
# SpringBoot项目
## spring cloud 架构的项目是基于springboot的，下面简单介绍一下springboot
1. jar包依赖，需要引入springboot的parent包，和应用中需要使用的具体的jar
```
   <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>1.5.2.RELEASE</version>
        <relativePath/>
    </parent>
    <dependency>  
        <groupId>org.springframework.boot</groupId>  
        <artifactId>spring-boot-starter-web</artifactId>
        <!-- 移除嵌入式tomcat插件,如果需要使用自己的Tomcat容器启动服务需要移除该jar，避免jar冲突 -->
        <exclusions>
            <exclusion>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-tomcat</artifactId>
            </exclusion>
        </exclusions>
    </dependency>
    <!-- 如果是web项目，在上面移除后，eclipse测试时需要提供tomcat的jar-->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-tomcat</artifactId>
        <scope>provided</scope>
    </dependency>
```
2. springboot默认是通过main函数启动应用
```
@SpringBootApplication
//引入其他配置文件
@PropertySource("classpath:dbaccount.yml")
@ComponentScan({"com.ule.wholesale.fxpurchase"})
public class FxServerApplication {

	public static void main(String[] args) {
        SpringApplication.run(FxServerApplication.class, args);
    }	
	
}
```
3. 如果想通过自己的Tomcat启动，需要继承 SpringBootServletInitializer
```
@SpringBootApplication
@PropertySource("classpath:dbaccount.yml")
@ComponentScan({"com.ule.wholesale.fxpurchase"})
public class FxServerApplication extends SpringBootServletInitializer{
	protected SpringApplicationBuilder configure(SpringApplicationBuilder builder){
        //builder.sources一定要指向springboot的主函数类
        return builder.sources(FxServerApplication.class);
	}
	public static void main(String[] args) {
        SpringApplication.run(FxServerApplication.class, args);
    }
}
```
4. spring boot的配置文件
```
server:
   port: 8801
   context-path: /fxPurchase
   error:
        path: /500.html
   session-timeout: 30
   session:
           cookie.http-only: true
           #cookie.domain= 
           #cookie.max-age: -1
           #cookie.path:  
           
# DATASOURCE
spring:
    jackson:
      date-format: yyyy-MM-dd HH:mm:ss
      time-zone: GMT+8
    application:
      name: FXPURCHASE-SERVICE1

    redis: 
      database: 0
      host: 127.0.0.1
      port: 6379
      password: 
      pool.max-active: 8
      pool.max-wait: -1
      pool.max-idle: 8
      pool.min-idle: 0
      timeout: 0
    datasource:
        name: postmall
        #url: jdbc:oracle:thin:@//172.24.144.126:1521/postmall
        #url: jdbc:mysql://172.25.201.63:3306/ule_uwds_selfsupport?useUnicode=true&characterEncoding=utf-8  
        #username: uleapp_uwds_self
        #password: ule.123
        # 使用druid数据源
        type: com.alibaba.druid.pool.DruidDataSource
        #driver-class-name: oracle.jdbc.driver.OracleDriver
        driver-class-name: com.mysql.jdbc.Driver
        #driver-class-name: com.p6spy.engine.spy.P6SpyDriver
        filters: stat
        maxActive: 20
        initialSize: 1
        maxWait: 60000
        minIdle: 1
        timeBetweenEvictionRunsMillis: 60000
        minEvictableIdleTimeMillis: 300000
        #validationQuery: select 1 from dual
        validationQuery: select 1 
        testWhileIdle: true
        testOnBorrow: false
        testOnReturn: false
        poolPreparedStatements: true
        maxOpenPreparedStatements: 20
              
     # HTTP ENCODING  
    http:  
        encoding.charset: UTF-8  
        encoding.enable: true  
        encoding.force: true  
    #spring mvc  
    mvc:
        view.prefix: /WEB-INF/view/
        view.suffix: .jsp
        static-path-pattern: /**
   
# MyBatis  
mybatis:  
    typeAliasesPackage: com.ule.wholesale.fxpurchase.server.vo
    mapperLocations: classpath:com/ule/wholesale/fxpurchase/mapper/*.xml
    configLocation: classpath:/mybatis-config.xml

logging:
  level:
   org.springframework: debug
   com.ule.wholesale.fxpurchase: debug
  

```
5. 引入其他配置文件的属性
```
properties:
  clientName: fxRuralOpcMerchant
  clientKey: B7C8BA415C580E9A3D84F835AD27FE94
  uploadTempDir: /data/postmall/tomcat/temp
  uploadFileToDFSUrl: //static.beta.ulecdn.com
  uploadFileUrl: http://upload.beta.ule.com/upload
  globalStaticServer1: //i0.beta.ulecdn.com
  globalStaticServer2: //i1.beta.ulecdn.com
  globalStaticServer3: //i2.beta.ulecdn.com
  searchDistrIpPort: cloudSearch.beta.uledns.com:9020
  itemAppkey: 7b8351500f54498f8f43bebd06d04eaa
  merchantWarehouse: http://soa.beta.uledns.com/wmsSearch/api/warehouse
  itemsStorage: http://wms.beta.ule.com/wmsApi3/inner/api/pur/inventory
  warehouseInfo: http://wms.beta.ule.com/wmsApi3/inner/api/pur/warehouse/contact
  cancelPurchaseOrder: http://wms.beta.ule.com/wmsApi3/inner/api/pur/stockIn/cancel
  cancelReturnOrder: http://wms.beta.ule.com/wmsApi3/inner/api/pur/so/cancel
  uleSelfSupport: http://cs.beta.ule.com/fxCsAdmin/api/fxMerchant/getUleOwnMerchant.do
  betaTestMerchant: 800100339-平台测试999
  
header:
  appkey: testkey
  token: testtoken

```
6. 属性文件将配置的属性值映射到对应的属性上
```
    package com.ule.wholesale.fxpurchase.web.conf;

    import org.springframework.beans.factory.annotation.Value;
    import org.springframework.boot.context.properties.ConfigurationProperties;
    import org.springframework.context.EnvironmentAware;
    import org.springframework.core.env.Environment;
    import org.springframework.stereotype.Component;

    @Component
    @ConfigurationProperties(prefix="properties")
    public class PropertiesConfiguration implements EnvironmentAware {
        
        @Value("${clientName}")
        private String tmpclientName;
        @Value("${clientKey}")
        private String tmpclientKey;
        ...
        
        public static String clientName;
        public static String clientKey;
        ...
        
        
        @Override
        public void setEnvironment(Environment arg0) {
            PropertiesConfiguration.clientName = tmpclientName;
            PropertiesConfiguration.clientKey = tmpclientKey;
            ...
        }	
    }
```


7. Durid数据源配置
```
package com.ule.wholesale.fxpurchase.server.conf;

import java.sql.SQLException;

import javax.sql.DataSource;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.bind.RelaxedPropertyResolver;
import org.springframework.context.EnvironmentAware;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.env.Environment;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import com.alibaba.druid.pool.DruidDataSource;

@Configuration  
@EnableTransactionManagement 
public class DataBaseConfiguration implements EnvironmentAware {

	private static Log log = LogFactory.getLog(DataBaseConfiguration.class);
	private RelaxedPropertyResolver propertyResolver;  
    @Autowired
	JDBCConfiguration jdbc;
	@Override
	public void setEnvironment(Environment env) {
		this.propertyResolver = new RelaxedPropertyResolver(env, "spring.datasource.");
	}

	@Bean(name="dataSource", destroyMethod = "close", initMethod="init")  
    @Primary  
    public DataSource dataSource() {  
        log.debug("Configruing Write druid DataSource");  
          
        DruidDataSource dataSource = new DruidDataSource();  
        log.info("jdbc.getUsername()="+jdbc.getUsername());
        log.info("jdbc.getUrl()="+jdbc.getUrl());
        log.info("jdbc.getPassword()="+jdbc.getPassword());
        log.info("driver-class-name="+propertyResolver.getProperty("driver-class-name"));
        dataSource.setUrl(jdbc.getUrl()); 
        dataSource.setUsername(jdbc.getUsername());//用户名  
        dataSource.setPassword(jdbc.getPassword());//密码  
        dataSource.setDriverClassName(propertyResolver.getProperty("driver-class-name"));  
        dataSource.setInitialSize(jdbc.getInitialSize());  
        dataSource.setMaxActive(jdbc.getMaxActive());  
        dataSource.setMinIdle(jdbc.getMinIdle());  
        dataSource.setMaxWait(jdbc.getMaxWait());  
        dataSource.setTimeBetweenEvictionRunsMillis(Integer.parseInt(propertyResolver.getProperty("timeBetweenEvictionRunsMillis")));  
        dataSource.setMinEvictableIdleTimeMillis(Integer.parseInt(propertyResolver.getProperty("minEvictableIdleTimeMillis")));  
        dataSource.setValidationQuery(jdbc.getValidationQuery());  
        dataSource.setTestOnBorrow(Boolean.getBoolean(propertyResolver.getProperty("testOnBorrow")));  
        dataSource.setTestWhileIdle(Boolean.getBoolean(propertyResolver.getProperty("testWhileIdle")));  
        dataSource.setTestOnReturn(Boolean.getBoolean(propertyResolver.getProperty("testOnReturn")));  
        dataSource.setPoolPreparedStatements(Boolean.getBoolean(propertyResolver.getProperty("poolPreparedStatements")));  
        dataSource.setMaxPoolPreparedStatementPerConnectionSize(Integer.parseInt(propertyResolver.getProperty("maxOpenPreparedStatements")));  
        //配置监控统计拦截的filters，去掉后监控界面sql无法统计，'wall'用于防火墙  
        try {
			dataSource.setFilters(propertyResolver.getProperty("filters"));
		} catch (SQLException e) {
			e.printStackTrace();
		} 
          
        return dataSource;  
    } 
	
}

```
8.  Mybatis配置
```
package com.ule.wholesale.fxpurchase.server.conf;

import javax.annotation.Resource;
//import javax.persistence.EntityManager;
import javax.sql.DataSource;

import org.apache.ibatis.session.SqlSessionFactory;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.mybatis.spring.annotation.MapperScan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.bind.RelaxedPropertyResolver;
import org.springframework.context.EnvironmentAware;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.io.DefaultResourceLoader;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.annotation.TransactionManagementConfigurer;

@Configuration  
@EnableTransactionManagement
@MapperScan(basePackages={"com.ule.wholesale.fxpurchase.server.mapper"})
public class MybatisConfiguration implements EnvironmentAware,TransactionManagementConfigurer {

	private static Logger logger = LoggerFactory.getLogger(MybatisConfiguration.class);  
	  
    private RelaxedPropertyResolver propertyResolver;  
      
    @Resource(name="dataSource")  
    private DataSource dataSource;
    
	@Override
	public void setEnvironment(Environment env) {
    	this.propertyResolver = new RelaxedPropertyResolver(env,"mybatis.");
	}
	
	@Bean  
    @ConditionalOnMissingBean  
    public SqlSessionFactory sqlSessionFactory() {  
        try {  
            SqlSessionFactoryBean sessionFactory = new SqlSessionFactoryBean();
            //dataSource = SpringBeanUtil.getBean(DataSource.class);
            sessionFactory.setDataSource(dataSource);  
            sessionFactory.setTypeAliasesPackage(propertyResolver.getProperty("typeAliasesPackage"));  
            sessionFactory.setMapperLocations(new PathMatchingResourcePatternResolver().getResources(propertyResolver.getProperty("mapperLocations")));
            sessionFactory.setConfigLocation(new DefaultResourceLoader().getResource(propertyResolver.getProperty("configLocation")));  
  
            return sessionFactory.getObject();  
        } catch (Exception e) {  
            logger.warn("Could not confiure mybatis session factory");  
            e.printStackTrace();
            return null;  
        }  
    }
	
	@Bean
	public SqlSessionTemplate sqlSessionTemplate(SqlSessionFactory sqlSessionFactory) {
		return new SqlSessionTemplate(sqlSessionFactory);
	}
	
	@Bean  
    @ConditionalOnMissingBean  
    public DataSourceTransactionManager transactionManager() {  
        return new DataSourceTransactionManager(dataSource);  
    }

	@Override
	public PlatformTransactionManager annotationDrivenTransactionManager() {
		return new DataSourceTransactionManager(dataSource);
	}

}

```
9. Mybatis的全局配置文件
```
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE configuration PUBLIC "-//mybatis.org//DTD Config 3.0//EN" "http://mybatis.org/dtd/mybatis-3-config.dtd">
        <configuration>    
        <!-- 全局参数 -->    
        <settings>        
                <!-- 使全局的映射器启用或禁用缓存。 -->        
                <setting name="cacheEnabled" value="true"/>        
                <!-- 全局启用或禁用延迟加载。当禁用时，所有关联对象都会即时加载。 -->        
                <setting name="lazyLoadingEnabled" value="true"/>        
                <!-- 当启用时，有延迟加载属性的对象在被调用时将会完全加载任意属性。否则，每种属性将会按需要加载。 -->        
                <setting name="aggressiveLazyLoading" value="true"/>        
                <!-- 是否允许单条sql 返回多个数据集  (取决于驱动的兼容性) default:true -->        
                <setting name="multipleResultSetsEnabled" value="true"/>        
                <!-- 是否可以使用列的别名 (取决于驱动的兼容性) default:true -->        
                <setting name="useColumnLabel" value="true"/>        
                <!-- 允许JDBC 生成主键。需要驱动器支持。如果设为了true，这个设置将强制使用被生成的主键，有一些驱动器不兼容不过仍然可以执行。  default:false  -->        
                <setting name="useGeneratedKeys" value="true"/>        
                <!-- 指定 MyBatis 如何自动映射 数据基表的列 NONE：不隐射　PARTIAL:部分  FULL:全部  -->        
                <setting name="autoMappingBehavior" value="PARTIAL"/>        
                <!-- 这是默认的执行类型  （SIMPLE: 简单； REUSE: 执行器可能重复使用prepared statements语句；BATCH: 执行器可以重复执行语句和批量更新）  -->        
                <setting name="defaultExecutorType" value="SIMPLE"/>        
                <!-- 使用驼峰命名法转换字段。 -->        
                <setting name="mapUnderscoreToCamelCase" value="true"/>        
                <!-- 设置本地缓存范围 session:就会有数据的共享  statement:语句范围 (这样就不会有数据的共享 ) defalut:session -->        
                <setting name="localCacheScope" value="SESSION"/>        
                <!-- 设置但JDBC类型为空时,某些驱动程序 要指定值,default:OTHER，插入空值时不需要指定类型 -->        
                <setting name="jdbcTypeForNull" value="NULL"/>    
         </settings>
        <plugins>        
                <plugin interceptor="com.github.pagehelper.PageHelper">            
                        <property name="dialect" value="mysql"/>            
                        <property name="offsetAsPageNum" value="false"/>            
                        <property name="rowBoundsWithCount" value="false"/>            
                        <property name="pageSizeZero" value="true"/>            
                        <property name="reasonable" value="false"/>            
                        <property name="supportMethodsArguments" value="false"/>            
                        <property name="returnPageInfo" value="none"/>        
               </plugin>    
      </plugins>
</configuration>
```
10. 所需要的jar包
```
        <dependency>  
            <groupId>org.mybatis.spring.boot</groupId>  
            <artifactId>mybatis-spring-boot-starter</artifactId>  
            <version>${mybatis}</version>  
        </dependency>
        <dependency>  
            <groupId>com.github.pagehelper</groupId>  
            <artifactId>pagehelper</artifactId>  
            <version>${pagehelper}</version>
        </dependency>
        <dependency>
            <groupId>com.alibaba</groupId>
            <artifactId>druid</artifactId>
            <version>${druid}</version>
        </dependency>
        <dependency>
		    <groupId>mysql</groupId>
		    <artifactId>mysql-connector-java</artifactId>
		  </dependency>
```
# Consul服务发现
## Spring cloud中服务发现主要使用Consul和Eureka这两种类型的比较多，demo中使用的是Consul
1. 依赖jar包
```
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-consul-discovery</artifactId>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
```
2. 在主函数上面添加注解 @EnableDiscoveryClient
3. consul配置
```
spring:
    cloud:
      consul:
      #instanceId默认诶服务名+端口（集群时id会重复）， 已经在Java中做了配置，值为spring.application.name-ip-port格式
      #port，healthCheckPath 针对本地测试使用，beta、prd均通过域名使用，端口处理为80
      #通过 tags=dev来判断是否为本地测试
      #本地测试时 healthCheckUrl、ipAddress配置无效(ipAddress为空会自动回去本机IP)，tags不等于dev或者不配置时port、healthCheckPath无效
        host: 127.0.0.1:8500
        #port: 8500
        enabled: true
        discovery:
          enabled: true
          #instanceId: ${spring.application.name}:${spring.application.instance_id:${random.value}}
          serviceName: ${spring.application.name}
          ipAddress: ${server-host}
          port: ${server.port}
          preferIpAddress: true
          healthCheckPath: ${server.context-path}/health
          healthCheckUrl: http://${server-host}${server.context-path}/health
          #healthCheckInterval: 10s 
          tags: dev            
endpoints:
  shutdown:
    enabled: true
    sensitive: true
  restart:
    enabled: true
  health:
    sensitive: false
```
# 创建server工程
## server工程里面的RestConstroller是下面要讲的feignclient的实现
> server 工程定义如下包名
>> com.ule.wholesale.server.conf #配置数据源，mybatis，属性文件的映射，已在springboot中描述过
>> com.ule.wholesale.server.dto # vo对象的扩展
>> com.ule.wholesale.server.filter #验证接口调用者是否合法
>> com.ule.wholesale.server.init #服务启动时需要初始的数据或者监听，InitializingBean
>> com.ule.wholesale.server.mapper #mybatis 的mapper 接口
>> com.ule.wholesale.server.msghandler #kafka消息处理
>> com.ule.wholesale.server.restcontroller #rest接口实现
>> com.ule.wholesale.server.schdule #定时任务执行
>> com.ule.wholesale.server.service #业务逻辑处理
>> com.ule.wholesale.server.vo #实体对象

> 1.  server 的配置文件中需要配置consul的服务发现，具体配置和依赖的jar已在consul中描述
> 2. conf 包中包括数据源配置、mybatis配置和属性文件映射 DataBaseConfiguration，MybatisConfiguration，ServerPropertiesConfiguration
> 3. 为了方便接口测试，我们在项目中引入了swagger2,jar依赖如下
>> 3.1 所依赖的jar和配置
```
        <dependency>
			<groupId>io.springfox</groupId>
			<artifactId>springfox-swagger2</artifactId>
			<version>${springfox_version}</version>
		</dependency>
		<dependency>
			<groupId>io.springfox</groupId>
			<artifactId>springfox-swagger-ui</artifactId>
			<version>${springfox_version}</version>
		</dependency>

package com.ule.wholesale.fxpurchase.server.conf;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import springfox.documentation.builders.ApiInfoBuilder;
import springfox.documentation.builders.PathSelectors;
import springfox.documentation.builders.RequestHandlerSelectors;
import springfox.documentation.service.ApiInfo;
import springfox.documentation.spi.DocumentationType;
import springfox.documentation.spring.web.plugins.Docket;
import springfox.documentation.swagger2.annotations.EnableSwagger2;

@Configuration
@EnableSwagger2
public class Swagger2 {

    @Bean
    public Docket createRestApi() {
        return new Docket(DocumentationType.SWAGGER_2)
                .apiInfo(apiInfo())
                .select()
                .apis(RequestHandlerSelectors.basePackage("com.ule.wholesale.fxpurchase.server"))
                .paths(PathSelectors.any())
                .build();
    }

    private ApiInfo apiInfo() {
        return new ApiInfoBuilder()
                .title("Spring Boot中使用Swagger2构建RESTful APIs")
                .description("更多Spring Cloud相关文章请关注更新内容")
                .termsOfServiceUrl("https://zhengzehou.github.io")
                .contact("郑明志")
                .version("1.0")
                .build();
    }

}
```
> 4. filter包验证调用者是否有权限，传输参数是否存在XSS注入和SQL注入
> 5. init包初始化启动时需要启动的监听（如kafka消费者监听服务），需要初始化的数据，或者需要在bean被创建之前需要做的操作
>> 5.1 本例初始化了consul服务发现的实例ID，有原来的随机值改为服务的IP和端口
```
package com.ule.wholesale.fxpurchase.server.init;

import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.InitializingBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.consul.discovery.ConsulDiscoveryProperties;
import org.springframework.stereotype.Component;
/**
 * 自定义初始化Consul
 * @author zhengmingzhi
 *
 */
@Component
public class ConsulInitializingBean implements InitializingBean {

	private static Logger logger = LoggerFactory.getLogger(ConsulInitializingBean.class);
	@Autowired
	ConsulDiscoveryProperties properties;
	@Override
	public void afterPropertiesSet() throws Exception {
		String port = System.getProperty("server.port");
		if(StringUtils.isNotBlank(port)){
			properties.setPort(Integer.valueOf(port));
		}
		logger.info("修改consul中instanceId的值，使用服务名+IP+端口,确保同一个服务在注册中心只有一条记录");
        //如果是本地测试使用本地IP和HealthCheckPath，非本地环境使用域名和80端口，通过tag=dev来判断
		if(properties.getTags().contains("dev")){
			properties.setHealthCheckUrl(null);
			properties.setIpAddress(getIpAddressAsInt());
		}else{
			properties.setHealthCheckPath(null);
			properties.setPort(80);
		}
		logger.info("start service serverPort="+properties.getPort());
        // InstanceId默认为applicationName+端口，使用applicationName+ip + 端口，防止集群时默认名字重复
		if(StringUtils.isBlank(properties.getInstanceId()))
			properties.setInstanceId(properties.getServiceName()+"-"+properties.getIpAddress()+"-"+properties.getPort());
	}

}

```
> 6. restcontroller rest接口实现，该包封装了所有的接口的实现，可以同feigclient封装为jar，也可以直接通过http调用
>> 示例代码如下
```
@RestController
@RequestMapping("/api/supplier")
@Api(value = "供应商接口服务类",tags = "供应商服务接口")  
public class SupplierServerController {

	private static Logger logger = LoggerFactory.getLogger(SupplierServerController.class);
	
	@Autowired
	private FXSupplierInfoService supplierInfoService;
	
	@RequestMapping(value = "/getSupplierListByPage",method=RequestMethod.POST)
	@ApiOperation("分页获取供应商列表")
	public ResultDTO<Map<String,Object>> getSupplierListByPage(
			@ApiParam(name="fxSupplierInfo",value="供应商对象",required=true)@RequestBody FXSupplierInfo fxSupplierInfo,
			@ApiParam(name="pageNum",value="页码",required=true)Integer pageNum,
			@ApiParam(name="pageSize",value="每页数量",required=true)Integer pageSize,String orderBy){
		logger.info("SupplierInfoController >>> getSupplierListByPage");
		ResultDTO<Map<String,Object>> rstDto = new ResultDTO<Map<String,Object>>();
		Map<String,Object> rstMap = new HashMap<String, Object>(); 
		PageInfo<FXSupplierInfo> pageInfo = supplierInfoService.getSupplierListByPage(fxSupplierInfo, pageNum, pageSize);
		rstMap.put("currentPage", pageInfo.getPageNum());
		rstMap.put("totalPage", pageInfo.getPages());
		rstMap.put("total", pageInfo.getTotal());
		rstMap.put("supplierList", pageInfo.getList());
		rstDto.setData(rstMap);
		rstDto.setCode("0");
		rstDto.setMsg("");
		return rstDto;
	}
}
```
# Spring Cloud 声明式REST客户端Feign
Feign是一个声明式的WebService客户端。使用Feign能让编写WebService客户端更加简单，它的使用方法是定义一个接口，然后在接口上添加注解，同时也支持JAX-RS标准的注解。SpringCloud对Feign进行了封装，使其支持SpringMVC标准注解和HttpMessageConverters。Feign可以与Consul、Eureka和Ribbon组合使用以支持负载均衡。  
FeignClient注解申明创建一个rest client Bean，可以直接通过Autowired注入使用，如果ribbon工程中启用，则会使用load balance进行后端请求调用，可以为FeignClient指定value表明要访问的serviceId
## 依赖jar
```
        <dependency>
            <groupId>org.springframework.cloud</groupId>
            <artifactId>spring-cloud-starter-feign</artifactId>
        </dependency>
```
## FeignClient的项目结构
`com.ule.wholesale.fxpurchase.api.client`
`com.ule.wholesale.fxpurchase.api.conf`
`com.ule.wholesale.fxpurchase.api.constants`
`com.ule.wholesale.fxpurchase.api.dto`
## FeignClient的serviceClient的实现代码示例
```
package com.ule.wholesale.fxpurchase.api.client;

import java.util.Map;
import org.springframework.cloud.netflix.feign.FeignClient;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import com.ule.wholesale.fxpurchase.common.util.ResultDTO;
/**
*ClientConstants.SERVICE_NAME 为server项目中指定的discovery下面的serviceName,一般保持和spring.application.name一致
*ClientConstants.SERVER_PATH contextPath
*/
@FeignClient(value=ClientConstants.SERVICE_NAME,path=ClientConstants.SERVER_PATH)
public interface OrderClientService {
	
	@RequestMapping("/api/order/fingdDetail/{orderId}")
	public ResultDTO<Map<String,Object>> fingdOrderDetailByOrderId(@PathVariable("orderId")Long orderId);
	@RequestMapping("/api/order/findOrderList")
	public ResultDTO<Map<String,Object>> findOrderList(@RequestBody Map<String,Object> params);
	@RequestMapping(value="/api/order/findPurchaseItemList",method=RequestMethod.POST)
	public ResultDTO<PageInfo<FXPurchaseOrderGoodsDto>> findPurchaseItemList(@RequestBody Map<String,Object> params,@RequestParam("pageNum")Integer pageNum,@RequestParam("pageSize")Integer pageSize);
}
```
## conf下配置了一个拦截器，用来传递head中的验证信息或者token信息
```
package com.ule.wholesale.fxpurchase.api.conf;

import java.util.Enumeration;

import javax.servlet.http.HttpServletRequest;

import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.ule.wholesale.fxpurchase.api.constants.ClientConstants;

import feign.RequestInterceptor;
import feign.RequestTemplate;

@Configuration
public class FeignClientsConfiguration {

	@Autowired
	HttpServletRequest request;
	@Bean
	public RequestInterceptor headerInterceptor() {
		return new RequestInterceptor() {
			@Override
			public void apply(RequestTemplate requestTemplate) {
                Enumeration<String> headerNames = request.getHeaderNames();
				if (headerNames != null) {
                    //此处可以对当前request中信息进行修改，或者传递到server的request，也可以不要
					while (headerNames.hasMoreElements()) {
						String name = headerNames.nextElement();
						Enumeration<String> values = request.getHeaders(name);
						while (values.hasMoreElements()) {
							requestTemplate.header(name, values.nextElement());
						}
					}
				}	
                for(String key : ClientConstants.headMap.keySet()){
                    if(ClientConstants.headMap.get(key) != null && StringUtils.isNotBlank(ClientConstants.headMap.get(key).toString()))
                        requestTemplate.header(key, ClientConstants.headMap.get(key).toString());
                }
			}
		};
	}
}
```
## 在调用者入口类上添加@EnableFeignClients注解
注解EnableFeignClients表明需要扫描使用FeignClient注解的接口，在代码中定义了@FeignClient表明该接口为一个feign接口通过ServiceId指定访问路径、RequestMapping表明相对路径
```
@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients("com.ule.wholesale.fxpurchase.api.*")
@PropertySource("classpath:dbaccount.yml")
@ComponentScan({"com.ule.wholesale.fxpurchase"})
public class FxServerApplication extends SpringBootServletInitializer{
	
	protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
		
        return builder.sources(FxServerApplication.class);
	}
	public static void main(String[] args) {
        SpringApplication.run(FxServerApplication.class, args);
    }
	
	
}
```
## Feign构造多参数的请求
```
    @RequestMapping(value = "/hello/{name}",method = RequestMethod.GET)
    public  ResultDTO<T> hello(@PathVariable("name") String name);

    @RequestMapping(value = "/params",method = RequestMethod.POST)
	public ResultDTO<T> testParam(@RequestParam("name")String name,@RequestParam("age")Integer age,@RequestParam("birthday")Date birthday);

    @RequestMapping(value = "/api/paramList",method = RequestMethod.POST,consumes = "application/json")
	public ResultDTO<T> testParamList(@RequestParam("name")String name,@RequestBody List<Integer> ages);

    @RequestMapping(value="/dto",method = RequestMethod.POST,consumes = "application/json")
	public ResultDTO<T> testDto(@RequestBody TestParamDto dto);

    @RequestMapping(value = "/list",method = RequestMethod.POST,consumes = "application/json")
	public ResultDTO<T> testList(@RequestBody List<TestParamDto> dtoList);
	
	@RequestMapping(value="/map",method = RequestMethod.POST, consumes = "application/json")
	public ResultDTO<T> testMap(@RequestBody Map<String,Object> params);

    @RequestMapping(value="/api/order/findPurchaseItemList",method=RequestMethod.POST)
	public ResultDTO<T> findPurchaseItemList(@RequestBody Map<String,Object> params,@RequestParam("pageNum")Integer pageNum,@RequestParam("pageSize")Integer pageSize);
```

# web应用通过Feign调用服务
##  依赖feignClient封装的jar
##  添加consul配置（如果使用eureka作为服务注册中心的配置eureka）
```
spring:
    consul:
        host: localhost
        port: 8500
        discovery:
          register: false
```
##  feign配置   [Ribbon的负载均衡策略](http://blog.csdn.net/rickiyeat/article/details/64918756) 
```
endpoints:
  shutdown:
    enabled: true
    sensitive: true
  restart:
    enabled: true
  health:
    sensitive: false
# Ribbon的负载均衡策略,默认就是随机的，不需要配置
{serviceName}:
  ribbon:
    NFLoadBalancerRuleClassName: com.netflix.loadbalancer.RandomRule 
#Spring Cloud中，如何解决Feign/Ribbon第一次请求失败的问题
#该配置是让Hystrix的超时时间改为5秒
hystrix:
  command:
    default: 
      execution: 
        isolation:
          thread.timeoutInMilliseconds: 5000
          strategy: SEMAPHORE
#禁用feign的hystrix
#feign.hystrix.enabled=false
feign:
   httpclient:
     enabled: true
   compression: 
   #请求和响应GZIP压缩支持
     request.enabled: true
     response.enabled: true
  #支持压缩的mime types
     request.mime-types: text/xml,application/xml,application/json
     request.min-request-size: 2048
```
##  feign重试次数和超时时间设置
```
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;

import feign.Request;
import feign.Retryer;

@Component
public class InitBean {
	
	@Value("${feignConnectTimeout:10000}")
	private Integer connectTimeoutMillis;
	@Value("${feignReadTimeout:60000}")
	private Integer readTimeoutMillis;
	
	// feign client默认的connectTimeout为10s，readTimeout为60.单纯设置timeout，可能没法立马见效，因为默认的retry为5次    
	@Bean
    Request.Options feignOptions() {
        return new Request.Options(/**connectTimeoutMillis**/connectTimeoutMillis, /** readTimeoutMillis **/readTimeoutMillis);
    }
	@Bean
    Retryer feignRetryer() {
        return Retryer.NEVER_RETRY;
    }
	
}
```
# 使用sleuth和zipkin
随着微服务数量不断增长，需要跟踪一个请求从一个微服务到下一个微服务的传播过程， Spring Cloud Sleuth 正是解决这个问题，它在日志中引入唯一ID，以保证微服务调用之间的一致性，这样你就能跟踪某个请求是如何从一个微服务传递到下一个。啟動服務`nohum java -jar zipkin.jar & `
## 引入配置
```
spring:
  zipkin:
      enabled: true
      base-url: http://192.168.175.129:9411
```
## 依赖jar
```
        <dependency>
			<groupId>org.springframework.cloud</groupId>
			<artifactId>spring-cloud-starter-sleuth</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.cloud</groupId>
			<artifactId>spring-cloud-starter-zipkin</artifactId>
		</dependency>
```
## 日志写入到zipkin配置
```
    //该配置是把日志写到zipkin
	@Bean
    public AlwaysSampler defaultSampler(){
        return new AlwaysSampler();
    }
```
## 访问请求时会打印相关日志
#### 先介绍几个相关术语：
Spring Cloud Sleuth自动装配所有Spring应用，因此你不用做任何事来让他工作
1. Span：基本工作单元，span通过一个64位ID唯一标识，trace以另一个64位ID表示，span还有其他数据信息，比如摘要、时间戳事件、关键值注释(tags)、span的ID、以及进度ID(通常是IP地址)
![span内容信息](/images/span.png)
2. Trace：一系列spans组成的一个树状结构
![trace内容信息](/images/trace.png)
3. Annotation：用来及时记录一个事件的存在，一些核心annotations用来定义一个请求的开始和结束
4. 可以通过Kibana等图形界面工具进行日志查看，可以看到事件的发生信息，Kibana的使用需要做相关配置。
#### 日志内容分析
##### 日志打印过程及顺序
cs - Client Sent -客户端发起一个请求，这个annotion描述了这个span的开始
sr - Server Received -服务端获得请求并准备开始处理它，如果将其sr减去cs时间戳便可得到网络延迟
ss - Server Sent -注解表明请求处理的完成(当请求返回客户端)，如果ss减去sr时间戳便可得到服务端需要的处理请求时间
cr - Client Received -表明span的结束，客户端成功接收到服务端的回复，如果cr减去cs时间戳便可得到客户端从服务端获取回复的所有所需时间
> 服务的依赖和执行过程
![服务的依赖和执行过程](/images/dependencies.png)
[appname,traceId,spanId,exportable]
[`service1`,2485ec27856c56f4,2485ec27856c56f4,true] 
[`service2`,2485ec27856c56f4,9aa10ee6fbde75fa,true]
[`service3`,2485ec27856c56f4,1210be13194bfe5,true] 
[`service2`,2485ec27856c56f4,9aa10ee6fbde75fa,true]
[`service4`,2485ec27856c56f4,1b1845262ffba49d,true] 
[`service2`,2485ec27856c56f4,9aa10ee6fbde75fa,true] 
[`service1`,2485ec27856c56f4,2485ec27856c56f4,true] 
> - 第一个参数appname,应用名
> - 第二个参数traceId，同一次调用traceId相同
> - 第三个参数spanId，同一次调用不同服务的spanId不同
> - 第四个参数表示是否写入到了zipki，TRUE为写入，FALSE未写入
##### 如果日志中要显示服务名需要在bootstrap.yml文件中进行配置spring.application.name=serverName，默认显示的是bootstrap