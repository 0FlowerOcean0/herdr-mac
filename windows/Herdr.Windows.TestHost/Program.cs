using System.Text;

Console.OutputEncoding = new UTF8Encoding(false);
Console.WriteLine("HERDR_CONPTY_READY");
Console.Out.Flush();

var input = Console.ReadLine();
Console.WriteLine($"HERDR_CONPTY_ECHO:{input}");
Console.Out.Flush();
