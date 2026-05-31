using UnityEditor;
using UnityEngine;

namespace Pioka.VpmExamplePackage
{
    internal static class ExampleLogger
    {
        [MenuItem("Tools/VPM Example Package/Log")]
        private static void Log()
        {
            Debug.Log("Hello from VPM Example Package!");
        }
    }
}
