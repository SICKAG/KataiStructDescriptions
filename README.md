# KataiStructDescriptions
This Repository includes Kaitai-Struct descriptions for the following data formats:
<ul>
    <li>Compact Format</li>
</ul>

## Getting started

To compile a Kaitai-Struct file the Kaitai-Struct compiler is required. There are two ways of doing this: via web or download.  

## Generating Code

### Local compiling
The Kaitai-Struct compiler can be downloaded from following page: (https://kaitai.io/#download) 

### Compile a Kaitai-Struct file
To compile the file to a specific programming language, go into the the folder, where the Kaitai description resides and open the command line.
Then type following command:  
```
Kaitai-Struct-compiler.bat [Filename] -t [programming language] 
Kaitai-Struct-compiler.bat compact_frame.ksy -t csharp   
```

The generated code will be appear in the same Folder.

### Web compiling

To compile the Kaitai file in web open the following page: (https://ide.kaitai.io/#)  

You can drag and drop the file into the browser. To compile the the file in a specific language, right click on the imported file, select "Generate Parser" and then select the language.
You will see the generated code on the right-hand side. Copy and paste it into an empty file and add it to your project.


## Dependency

### Kaitai Struct runtime libraries
To receive data with the Kaitai-Struct parser, the the runtime libraries for the programming language of your choice must be included in your application. They can be found here: https://kaitai.io/. To include the libraries use the respective mechanisms of your development environment.

As an example, for C# run the following command:

``` dotnet
$ dotnet add package KaitaiStruct.Runtime.CSharp --version 0.10.0
```

## Receive data
The C# code below demonstrates how data can be received and converted into Compact Format using the generated code. For other programming languages similar code can be used.

``` csharp
using Kaitai;
using System.Net.Sockets;
using System.Net;

class Example
{

    static CompactFrame[] ReadUDPPacket(string IPAdress, int port, int numberOfSegments)
    {
        CompactFrame[] compactFrames = new CompactFrame[numberOfSegments];
        using UdpClient udpClient = new UdpClient(port);
        IPEndPoint remoteEndPoint = new IPEndPoint(IPAddress.Parse(IPAdress), 2115);

        for (int i = 0; i < numberOfSegments; i++)
        {
            // Receive UDP Packet
            byte[] result = udpClient.Receive(ref remoteEndPoint);
            byte[] receiveBuffer = result;

            // Convert the UDP Packet to a Stream for Kaitai and convert stream
            Stream stream = new MemoryStream(receiveBuffer);
            CompactFrame cf = CompactFrame.FromIO(stream); //This is a Kaitai-Struct Function
            compactFrames[i] = cf;

        }
        udpClient.Close();
        return compactFrames;
    }

    static void Main()
    {
        //Receive 100 segments from IP address 192.168.0.1 via port 2115
        CompactFrame[] cf = ReadUDPPacket("192.168.0.100", 2115, 100);

        //Output example
        foreach (CompactFrame frame in cf)
        {
            if (frame == null) continue;
            string frameNumber = frame.Module[0].Metadata.FrameNumber.ToString();
            string segmentCounter = frame.Module[0].Metadata.SegmentCounter.ToString();
            string startAngle = frame.Module[0].Metadata.ThetaStart[0].ToString();
            string distance = frame.Module[0].Beams[0].Lines[0].Echos[0].Distance.ToString();
            Console.WriteLine($"FrameNumber: {frameNumber}  SegmentCounter: {segmentCounter,-3}  Start Angle: {startAngle,-12}  Distance: {distance}");
        }
    }
}
```

## Known Issues
### Missing FromIO method
When the code is generated it can happen that the FromIO method is missing. E.g In C# this method is missing, in python it is generated. To add this method, add these lines of code in the "ComapctFrame" file after the first FromFile() method right at the beginning.

C# example

``` csharp
public static CompactFrame FromIO(Stream io)
{
    return new CompactFrame(new KaitaiStream(io));
}
```