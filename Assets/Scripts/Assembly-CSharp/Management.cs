using UnityEngine.SceneManagement;

public class Management
{
    public static bool isLogo = true;

    public static string IpServer = "NRO Bear:160.191.245.239:14445:0,0,0";

    public static string LinkWeb = "@ngu";

    private static TabType[] tabTypes = new TabType[]
    {
        TabType.Tab1,
        TabType.Tab2
    };

    private static string[] SceneNames = new string[]
    {
         "NROL",
         "NROL1"
    };
    public static TabType tab;

    private static bool SceneLoad(string sceneName)
    {
        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            if (SceneManager.GetSceneAt(i).name == sceneName)
            {
                return true;
            }
        }
        return false;
    }

    public static void ChangeTab(int index)
    {
        tab = tabTypes[index];
        if (!SceneLoad(SceneNames[index]))
        {
            SceneManager.LoadScene(SceneNames[index], LoadSceneMode.Additive);
        }
    }
}

