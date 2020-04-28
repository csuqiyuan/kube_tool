package scp;

public class Main {
    public static void main(String[] args){
        String hostname = args[0];
        int port = Integer.parseInt(args[1]);//22 usually the default port
        String username = args[2];
        String password = args[3];
        ConnectUtil connectUtil = new ConnectUtil();
        connectUtil.scp(hostname,port,username,password);
    }
}
