namespace Herdr.Windows.Models;

public sealed record TerminalTheme(
    string Name,
    string Title,
    bool IsLight,
    TerminalPalette Palette);

public sealed record TerminalPalette(
    string Background,
    string Foreground,
    string Cursor,
    string SelectionBackground,
    string[] Ansi)
{
    public object ToWebTheme() => new
    {
        background = Background,
        foreground = Foreground,
        cursor = Cursor,
        selectionBackground = SelectionBackground,
        black = Ansi[0],
        red = Ansi[1],
        green = Ansi[2],
        yellow = Ansi[3],
        blue = Ansi[4],
        magenta = Ansi[5],
        cyan = Ansi[6],
        white = Ansi[7],
        brightBlack = Ansi[8],
        brightRed = Ansi[9],
        brightGreen = Ansi[10],
        brightYellow = Ansi[11],
        brightBlue = Ansi[12],
        brightMagenta = Ansi[13],
        brightCyan = Ansi[14],
        brightWhite = Ansi[15]
    };
}

public static class TerminalThemeCatalog
{
    public static IReadOnlyList<TerminalTheme> All { get; } =
    [
        Theme("catppuccin", "Catppuccin Mocha", false, "181825", "CDD6F4", "89B4FA", "313244", "181825,F38BA8,A6E3A1,F9E2AF,89B4FA,CBA6F7,94E2D5,CDD6F4,6C7086,F38BA8,A6E3A1,F9E2AF,89B4FA,CBA6F7,94E2D5,CDD6F4"),
        Theme("catppuccin-latte", "Catppuccin Latte", true, "EFF1F5", "4C4F69", "1E66F5", "CCD0DA", "EFF1F5,D20F39,40A02B,DF8E1D,1E66F5,8839EF,179299,4C4F69,9CA0B0,D20F39,40A02B,DF8E1D,1E66F5,8839EF,179299,4C4F69"),
        Theme("terminal", "Terminal", false, "101014", "EAEAEA", "5E9EFF", "303039", "101014,D95468,68B723,E6C446,5E9EFF,A88BFA,55C2D9,EAEAEA,66666D,FF6B7A,87D75F,FFE46B,83B6FF,C2A7FF,7AD7E8,FFFFFF"),
        Theme("tokyo-night", "Tokyo Night", false, "1A1B26", "C0CAF5", "7AA2F7", "24283B", "1A1B26,F7768E,9ECE6A,E0AF68,7AA2F7,BB9AF7,7DCFFF,C0CAF5,565F89,F7768E,9ECE6A,E0AF68,7AA2F7,BB9AF7,7DCFFF,C0CAF5"),
        Theme("tokyo-night-day", "Tokyo Night Day", true, "E1E2E7", "3760BF", "2E7DE9", "C4C8DA", "E1E2E7,F52A65,587539,8C6C3E,2E7DE9,7847BD,118C74,3760BF,8990B3,F52A65,587539,8C6C3E,2E7DE9,7847BD,118C74,3760BF"),
        Theme("dracula", "Dracula", false, "282A36", "F8F8F2", "BD93F9", "44475A", "282A36,FF5555,50FA7B,F1FA8C,8BE9FD,FF79C6,8BE9FD,F8F8F2,6272A4,FF5555,50FA7B,F1FA8C,8BE9FD,FF79C6,8BE9FD,F8F8F2"),
        Theme("nord", "Nord", false, "2E3440", "ECEFF4", "88C0D0", "3B4252", "2E3440,BF616A,A3BE8C,EBCB8B,81A1C1,B48EAD,8FBCBB,ECEFF4,4C566A,BF616A,A3BE8C,EBCB8B,81A1C1,B48EAD,8FBCBB,ECEFF4"),
        Theme("gruvbox", "Gruvbox Dark", false, "282828", "EBDBB2", "D79921", "3C3836", "282828,FB4934,B8BB26,FABD2F,83A598,D3869B,8EC07C,EBDBB2,928374,FB4934,B8BB26,FABD2F,83A598,D3869B,8EC07C,EBDBB2"),
        Theme("gruvbox-light", "Gruvbox Light", true, "FBF1C7", "3C3836", "076678", "EBDBB2", "FBF1C7,9D0006,79740E,B57614,076678,8F3F71,427B58,3C3836,928374,9D0006,79740E,B57614,076678,8F3F71,427B58,3C3836"),
        Theme("one-dark", "One Dark", false, "282C34", "ABB2BF", "61AFEF", "2C313A", "282C34,E06C75,98C379,E5C07B,61AFEF,C678DD,56B6C2,ABB2BF,5C6370,E06C75,98C379,E5C07B,61AFEF,C678DD,56B6C2,ABB2BF"),
        Theme("one-light", "One Light", true, "FAFAFA", "383A42", "4078F2", "F0F0F1", "FAFAFA,E45649,50A14F,C18401,4078F2,A626A4,0184BC,383A42,A0A1A7,E45649,50A14F,C18401,4078F2,A626A4,0184BC,383A42"),
        Theme("solarized", "Solarized Dark", false, "002B36", "93A1A1", "268BD2", "073642", "002B36,DC322F,859900,B58900,268BD2,D33682,2AA198,93A1A1,586E75,DC322F,859900,B58900,268BD2,D33682,2AA198,93A1A1"),
        Theme("solarized-light", "Solarized Light", true, "FDF6E3", "657B83", "268BD2", "EEE8D5", "FDF6E3,DC322F,859900,B58900,268BD2,D33682,2AA198,657B83,93A1A1,DC322F,859900,B58900,268BD2,D33682,2AA198,657B83"),
        Theme("kanagawa", "Kanagawa", false, "1F1F28", "DCD7BA", "7E9CD8", "2A2A37", "1F1F28,C34043,76946A,C0A36E,7E9CD8,957FB8,7FB4CA,DCD7BA,727169,C34043,76946A,C0A36E,7E9CD8,957FB8,7FB4CA,DCD7BA"),
        Theme("kanagawa-lotus", "Kanagawa Lotus", true, "F2ECBC", "545464", "4D699B", "DCD5AC", "F2ECBC,C84053,6F894E,77713F,4D699B,624C83,4E8CA2,545464,A09CAC,C84053,6F894E,77713F,4D699B,624C83,4E8CA2,545464"),
        Theme("rose-pine", "Rose Pine", false, "191724", "E0DEF4", "C4A7E7", "1F1D2E", "191724,EB6F92,31748F,F6C177,31748F,C4A7E7,9CCFD8,E0DEF4,6E6A86,EB6F92,31748F,F6C177,31748F,C4A7E7,9CCFD8,E0DEF4"),
        Theme("rose-pine-dawn", "Rose Pine Dawn", true, "FAF4ED", "464261", "907AA9", "F2E9E1", "FAF4ED,B4637A,286983,EA9D34,286983,907AA9,56949F,464261,9893A5,B4637A,286983,EA9D34,286983,907AA9,56949F,464261"),
        Theme("vesper", "Vesper", false, "1A1A1A", "FFFFFF", "FFC799", "232323", "1A1A1A,FF8080,99FFE4,FFC799,B0B0B0,FFD1A8,66DDCC,FFFFFF,5C5C5C,FF8080,99FFE4,FFC799,B0B0B0,FFD1A8,66DDCC,FFFFFF")
    ];

    public static TerminalTheme Find(string? name) =>
        All.FirstOrDefault(theme => string.Equals(theme.Name, name, StringComparison.Ordinal)) ?? All[0];

    private static TerminalTheme Theme(
        string name,
        string title,
        bool isLight,
        string background,
        string foreground,
        string cursor,
        string selection,
        string ansi) => new(
            name,
            title,
            isLight,
            new TerminalPalette(
                Hex(background),
                Hex(foreground),
                Hex(cursor),
                Hex(selection),
                ansi.Split(',').Select(Hex).ToArray()));

    private static string Hex(string value) => $"#{value.ToLowerInvariant()}";
}
