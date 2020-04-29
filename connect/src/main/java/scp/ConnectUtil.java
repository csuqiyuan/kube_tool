package scp;

import ch.ethz.ssh2.Connection;
import ch.ethz.ssh2.SCPClient;

import java.io.IOException;

public class ConnectUtil {


    public void scp(String hostname, int port, String username, String password) {
        Connection conn = new Connection(hostname, port);
        try {
            //连接到主机
            conn.connect();
            //使用用户名和密码校验
            boolean isconn = conn.authenticateWithPassword(username, password);
            if (!isconn) {
                System.out.println("用户名称或者是密码不正确");
            } else {
                System.out.println("已经连接OK");

                //可以用于两个机器间传文件
                SCPClient clt = conn.createSCPClient();
                clt.put("/etc/kubernetes/admin.conf", "/etc/kubernetes");
            }
        } catch (IOException e) {
            System.out.println(e.getMessage());
            e.printStackTrace();
        } finally {
            //连接的Session和Connection对象都需要关闭
            if (conn != null) {
                conn.close();
            }
        }
    }
}
